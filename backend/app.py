import os
import subprocess
import uuid
from flask import Flask, request, jsonify, g
import boto3
import pymysql
import sqlite3
import json
import logging
import time
import shutil
import sys
from logging.handlers import RotatingFileHandler

AWS_REGION = os.getenv('AWS_REGION', 'eu-central-1')
S3_BUCKET = os.getenv('S3_BUCKET', 'license-plates-images-bucket')
LOCAL_MODE = os.getenv('LOCAL_MODE', 'false').lower() == 'true'
UPLOAD_DIR = os.getenv('UPLOAD_DIR', 'uploads')

# Logging configuration (stdout + rotating file)
LOG_LEVEL = os.getenv('LOG_LEVEL', 'DEBUG' if LOCAL_MODE else 'INFO').upper()
numeric_level = getattr(logging, LOG_LEVEL, logging.INFO)
LOG_FILE = os.getenv('LOG_FILE', os.path.join(os.path.dirname(__file__), 'logs', 'app.log'))
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

root_logger = logging.getLogger()
root_logger.handlers.clear()
root_logger.setLevel(numeric_level)

formatter = logging.Formatter('[%(asctime)s] %(levelname)s %(message)s')

stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setLevel(numeric_level)
stream_handler.setFormatter(formatter)
root_logger.addHandler(stream_handler)

file_handler = RotatingFileHandler(LOG_FILE, maxBytes=5*1024*1024, backupCount=5, encoding='utf-8')
file_handler.setLevel(numeric_level)
file_handler.setFormatter(formatter)
root_logger.addHandler(file_handler)

# ALPR configuration
ALPR_COUNTRY = os.getenv('ALPR_COUNTRY', 'eu')

DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_USER = os.getenv('DB_USER', 'root')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'root')
DB_NAME = os.getenv('DB_NAME', 'license_plates_db')

app = Flask(__name__)

s3_client = None if LOCAL_MODE else boto3.client('s3', region_name=AWS_REGION)

SQLITE_PATH = os.path.join(os.path.dirname(__file__), 'local.db') if LOCAL_MODE else None

# Per-request logging
@app.before_request
def _log_request_start():
    g._req_start_time = time.time()
    logging.info("HTTP %s %s", request.method, request.path)

@app.after_request
def _log_request_end(response):
    try:
        started = getattr(g, '_req_start_time', None)
        dur_ms = int((time.time() - started) * 1000) if started else None
    except Exception:
        dur_ms = None
    logging.info("HTTP %s %s -> %s%s",
                 request.method,
                 request.path,
                 response.status_code,
                 f" ({dur_ms}ms)" if dur_ms is not None else "")
    return response

if LOCAL_MODE:
    # Ensure local DB and table exist
    conn = sqlite3.connect(SQLITE_PATH)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS plates (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plate_number TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                image_path TEXT
            )
            """
        )
        conn.commit()
    finally:
        conn.close()

@app.route('/upload', methods=['POST'])
@app.route('/api/upload', methods=['POST'])
def upload_image():
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400

    image_file = request.files['file']
    if image_file.filename == '':
        return jsonify({'error': 'Empty file name'}), 400

    unique_name = f"{uuid.uuid4()}.jpg"

    local_path = None
    if LOCAL_MODE:
        if not os.path.exists(UPLOAD_DIR):
            os.makedirs(UPLOAD_DIR, exist_ok=True)
        local_path = os.path.join(UPLOAD_DIR, unique_name)
        image_file.save(local_path)
    else:
        tmp_path = f"/tmp/{unique_name}"
        image_file.save(tmp_path)
        s3_client.upload_file(tmp_path, S3_BUCKET, unique_name)
        local_path = tmp_path

    # Log request and environment details
    try:
        file_size = os.path.getsize(local_path) if os.path.exists(local_path) else None
    except Exception:
        file_size = None
    logging.info(
        "Upload received: name=%s size=%sB remote=%s local_mode=%s",
        image_file.filename,
        file_size,
        request.remote_addr,
        LOCAL_MODE,
    )
    logging.info(
        "ALPR env: country=%s config_file=%s alpr_path=%s",
        ALPR_COUNTRY,
        os.getenv('OPENALPR_CONFIG_FILE'),
        shutil.which('alpr'),
    )

    try:
        # Resolve ALPR binary and config
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        bundled_dir = os.path.join(repo_root, 'OpenALPR', 'openalpr-2.3.0-win-64bit', 'openalpr_64')
        alpr_bin = shutil.which('alpr')
        bundled_alpr = os.path.join(bundled_dir, 'alpr.exe')
        if not alpr_bin and os.path.exists(bundled_alpr):
            alpr_bin = bundled_alpr
        conf_path = os.getenv('OPENALPR_CONFIG_FILE')
        if not conf_path:
            bundled_conf = os.path.join(bundled_dir, 'openalpr.conf')
            if os.path.exists(bundled_conf):
                conf_path = bundled_conf

        logging.info(
            "ALPR resolved paths: alpr_bin=%s config_file=%s bundled_dir_exists=%s",
            alpr_bin,
            conf_path,
            os.path.isdir(bundled_dir),
        )

        if not alpr_bin:
            raise FileNotFoundError('alpr binary not found on PATH or bundled directory')

        alpr_args = [alpr_bin, '-j', '-n', '5', '-c', ALPR_COUNTRY, local_path]
        logging.info("Invoking ALPR: %s", ' '.join(alpr_args))
        env = os.environ.copy()
        if conf_path:
            env['OPENALPR_CONFIG_FILE'] = conf_path
        t0 = time.time()
        proc = subprocess.run(alpr_args, text=True, capture_output=True, timeout=20, env=env)
        duration_ms = int((time.time() - t0) * 1000)
        logging.info("ALPR finished in %sms with rc=%s", duration_ms, proc.returncode)

        if proc.returncode != 0:
            logging.error("ALPR error: rc=%s stderr=%s stdout=%s", proc.returncode, proc.stderr, proc.stdout)
            payload = {'error': 'OpenALPR failed'}
            if LOCAL_MODE:
                payload['debug'] = {
                    'return_code': proc.returncode,
                    'stderr': proc.stderr,
                    'stdout': proc.stdout,
                    'duration_ms': duration_ms,
                    'alpr_path': alpr_bin,
                    'config_file': conf_path,
                    'country': ALPR_COUNTRY,
                }
            return jsonify(payload), 500

        alpr_output = proc.stdout
        logging.debug("[ALPR] Raw output: %s", alpr_output)
        plate = parse_plate(alpr_output)
        logging.info("[ALPR] Parsed plate: %s", plate)

    except subprocess.TimeoutExpired:
        logging.error("ALPR timed out")
        payload = {'error': 'OpenALPR timed out'}
        if LOCAL_MODE:
            payload['debug'] = {
                'alpr_path': alpr_bin if 'alpr_bin' in locals() else None,
                'config_file': conf_path if 'conf_path' in locals() else None,
                'country': ALPR_COUNTRY,
            }
        return jsonify(payload), 504
    except Exception as e:
        logging.exception("ALPR invocation failed: %s", e)
        return jsonify({'error': f'OpenALPR invocation failed: {str(e)}'}), 500

    save_to_db(plate, local_path if LOCAL_MODE else None)
    if os.path.exists(local_path) and not LOCAL_MODE:
        os.remove(local_path)

    response = {
        'plate': plate,
        'make': None,
        'model': None,
        'color': None
    }

    # Include debug candidates in LOCAL_MODE
    if LOCAL_MODE:
        try:
            data = json.loads(alpr_output)
            response['debug'] = {
                'country': ALPR_COUNTRY,
                'alpr_path': alpr_bin if 'alpr_bin' in locals() else shutil.which('alpr'),
                'config_file': conf_path if 'conf_path' in locals() else os.getenv('OPENALPR_CONFIG_FILE'),
                'results': data.get('results', []),
            }
        except Exception:
            pass

    return jsonify(response)

def parse_plate(alpr_output: str) -> str:
    # Prefer JSON parsing (alpr -j) for reliable extraction
    try:
        data = json.loads(alpr_output)
        results = data.get('results', [])
        if results:
            top = results[0]
            # Primary plate string
            plate = top.get('plate')
            if plate:
                return plate
            # Fallback: best candidate if present
            candidates = top.get('candidates') or []
            if candidates:
                best = candidates[0].get('plate')
                if best:
                    return best
    except Exception:
        pass

    # Fallback: legacy text parsing if JSON not available
    for line in alpr_output.splitlines():
        if line.lower().startswith('plate'):
            parts = line.split()
            if len(parts) >= 2:
                return parts[1]
    return 'UNKNOWN'

def save_to_db(plate, image_path=None):
    if LOCAL_MODE:
        conn = sqlite3.connect(SQLITE_PATH)
        try:
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO plates (plate_number, image_path) VALUES (?, ?)",
                (plate, image_path),
            )
            conn.commit()
            logging.info("Saved to local DB: plate=%s path=%s", plate, image_path)
        finally:
            conn.close()
        return

    connection = pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor
    )
    try:
        with connection.cursor() as cursor:
            sql = """
                INSERT INTO plates (plate_number, image_path)
                VALUES (%s, %s)
            """
            cursor.execute(sql, (plate, image_path))
        connection.commit()
        logging.info("Saved to MySQL DB: plate=%s path=%s", plate, image_path)
    finally:
        connection.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)