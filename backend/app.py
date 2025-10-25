import os
import subprocess
import uuid
import datetime
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
from flask_cors import CORS
from plate_service import PlateService
from vehicle_attributes_service import VehicleAttributesService

AWS_REGION = os.getenv('AWS_REGION', 'eu-central-1')
S3_BUCKET = os.getenv('S3_BUCKET', 'license-plates-images-bucket')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL', '')
ASYNC_PROCESSING = os.getenv('ASYNC_PROCESSING', 'false').lower() == 'true'
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

file_handler = RotatingFileHandler(LOG_FILE, maxBytes=5*1024*1024, backupCount=5, encoding='utf-8')
file_handler.setLevel(numeric_level)
file_handler.setFormatter(formatter)
root_logger.addHandler(file_handler)

# Route Werkzeug/Flask logs to root file handler only
for _name in ('werkzeug', 'flask.app'):
    _logger = logging.getLogger(_name)
    _logger.handlers.clear()
    _logger.setLevel(numeric_level)
    _logger.propagate = True

# ALPR configuration
ALPR_COUNTRY = os.getenv('ALPR_COUNTRY', 'eu')

# AWS clients
sqs_client = None if LOCAL_MODE else boto3.client('sqs', region_name=AWS_REGION)
s3_client = None if LOCAL_MODE else boto3.client('s3', region_name=AWS_REGION)

DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_USER = os.getenv('DB_USER', 'root')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'root')
DB_NAME = os.getenv('DB_NAME', 'license_plates_db')

# Database configuration dict for pymysql
DATABASE_CONFIG = {
    'host': DB_HOST,
    'user': DB_USER,
    'password': DB_PASSWORD,
    'database': DB_NAME
}

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

s3_client = None if LOCAL_MODE else boto3.client('s3', region_name=AWS_REGION)

SQLITE_PATH = os.path.join(os.path.dirname(__file__), 'local.db') if LOCAL_MODE else None

# Single PlateService instance
plate_service = PlateService()
vehicle_attr_service = VehicleAttributesService()

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
    # Ensure local DB and table exist with correct schema
    conn = sqlite3.connect(SQLITE_PATH)
    try:
        cur = conn.cursor()
        
        # Check if table exists and has the correct schema
        cur.execute("PRAGMA table_info(plates)")
        columns = [row[1] for row in cur.fetchall()]
        
        # If table doesn't exist or has wrong schema, recreate it
        expected_columns = ['id', 'timestamp', 'plate_number', 'color', 'make', 'model']
        if not columns or columns != expected_columns:
            logging.info("Recreating plates table with correct schema")
            cur.execute("DROP TABLE IF EXISTS plates")
            cur.execute(
                """
                CREATE TABLE plates (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT (datetime('now', 'utc')),
                    plate_number TEXT,
                    color TEXT,
                    make TEXT,
                    model TEXT
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

    # Check if async processing is enabled
    if ASYNC_PROCESSING and not LOCAL_MODE:
        # Send expect a 202 Accepted response with processing status
        timestamp = datetime.datetime.now().isoformat()
        
        # Send message to SQS queue
        try:
            message_body = {
                'image_key': unique_name,
                'timestamp': timestamp,
                'bucket': S3_BUCKET
            }
            
            sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(message_body)
            )
            
            logging.info("Message sent to SQS queue for async processing: %s", unique_name)
            
            response = {
                'status': 'processing',
                'timestamp': timestamp,
                'key': unique_name
            }
            
            return jsonify(response), 202
            
        except Exception as e:
            logging.exception("Failed to send message to SQS queue: %s", e)
            return jsonify({'error': 'Failed to queue processing request'}), 500
    
    # Synchronous processing (fallback or LOCAL_MODE)
    try:
        result = plate_service.recognize(local_path, timeout_seconds=20)
        if result['return_code'] != 0:
            logging.error("ALPR error: rc=%s stderr=%s stdout=%s", result['return_code'], result['stderr'], result['stdout'])
            payload = {'error': 'OpenALPR failed'}
            if LOCAL_MODE:
                payload['debug'] = {
                    'return_code': result['return_code'],
                    'stderr': result['stderr'],
                    'stdout': result['stdout'],
                    'duration_ms': result['duration_ms'],
                    'alpr_path': result['alpr_path'],
                    'config_file': result['config_file'],
                    'country': result['country'],
                }
            return jsonify(payload), 500

        alpr_output = result['stdout']
        plate = result['plate']
        logging.debug("[ALPR] Raw output: %s", alpr_output)
        logging.info("[ALPR] Parsed plate: %s", plate)

    except subprocess.TimeoutExpired:
        logging.error("ALPR timed out")
        payload = {'error': 'OpenALPR timed out'}
        if LOCAL_MODE:
            payload['debug'] = {
                'alpr_path': getattr(plate_service, 'alpr_path', None),
                'config_file': getattr(plate_service, 'config_file', None),
                'country': getattr(plate_service, 'country', None) or ALPR_COUNTRY,
            }
        return jsonify(payload), 504
    except Exception as e:
        logging.exception("ALPR invocation failed: %s", e)
        return jsonify({'error': f'OpenALPR invocation failed: {str(e)}'}), 500

    # Analyze vehicle attributes
    attrs = vehicle_attr_service.analyze(local_path)
    logging.info("Vehicle attributes: make=%s model=%s color=%s", attrs.get('make'), attrs.get('model'), attrs.get('color'))

    save_to_db(plate, attrs)
    if os.path.exists(local_path) and not LOCAL_MODE:
        os.remove(local_path)

    response = {
        'plate': plate,
        'make': attrs.get('make'),
        'model': attrs.get('model'),
        'color': attrs.get('color')
    }

    # Include debug candidates in LOCAL_MODE
    if LOCAL_MODE:
        try:
            data = json.loads(alpr_output)
            response['debug'] = {
                'country': getattr(plate_service, 'country', None) or ALPR_COUNTRY,
                'alpr_path': getattr(plate_service, 'alpr_path', None) or shutil.which('alpr'),
                'config_file': getattr(plate_service, 'config_file', None) or os.getenv('OPENALPR_CONFIG_FILE'),
                'results': data.get('results', []),
                'vehicle_attributes': attrs,
            }
        except Exception:
            pass

    logging.info("API response attributes: make=%s model=%s color=%s", response.get('make'), response.get('model'), response.get('color'))

    return jsonify(response)

@app.route('/api/cars/query', methods=['POST'])
def query_cars():
    try:
        data = request.get_json()
        license_plates = data.get('licensePlates', [])
        colors = data.get('colors', [])
        makes = data.get('makes', [])
        models = data.get('models', [])
        query_date = data.get('queryDate')
        query_hour = data.get('queryHour')
        query_minute = data.get('queryMinute')
        query_second = data.get('querySecond')
        
        # Build query conditions
        conditions = []
        params = []
        
        if license_plates:
            placeholders = ','.join(['?' if LOCAL_MODE else '%s'] * len(license_plates))
            conditions.append(f"plate_number IN ({placeholders})")
            params.extend(license_plates)
            
        if colors:
            placeholders = ','.join(['?' if LOCAL_MODE else '%s'] * len(colors))
            conditions.append(f"color IN ({placeholders})")
            params.extend(colors)
            
        if makes:
            placeholders = ','.join(['?' if LOCAL_MODE else '%s'] * len(makes))
            conditions.append(f"make IN ({placeholders})")
            params.extend(makes)
            
        if models:
            placeholders = ','.join(['?' if LOCAL_MODE else '%s'] * len(models))
            conditions.append(f"model IN ({placeholders})")
            params.extend(models)
            
        # Handle date filtering
        if query_date:
            # Convert date to string format for comparison
            if isinstance(query_date, str):
                if 'T' in query_date:
                    date_str = query_date.split('T')[0]
                else:
                    date_str = query_date
            else:
                date_str = str(query_date)
            
            logging.info("Date filtering: query_date=%s, date_str=%s", query_date, date_str)
            conditions.append("DATE(timestamp) = ?" if LOCAL_MODE else "DATE(timestamp) = %s")
            params.append(date_str)
            
        # Handle individual time component filtering
        if query_hour is not None:
            conditions.append("CAST(strftime('%H', timestamp) AS INTEGER) = ?" if LOCAL_MODE else "HOUR(timestamp) = %s")
            params.append(query_hour)
            
        if query_minute is not None:
            conditions.append("CAST(strftime('%M', timestamp) AS INTEGER) = ?" if LOCAL_MODE else "MINUTE(timestamp) = %s")
            params.append(query_minute)
            
        if query_second is not None:
            conditions.append("CAST(strftime('%S', timestamp) AS INTEGER) = ?" if LOCAL_MODE else "SECOND(timestamp) = %s")
            params.append(query_second)
        
        # Build query (include id for updates)
        query = "SELECT id, timestamp, plate_number, color, make, model FROM plates"
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY timestamp DESC"
        
        logging.info("Query: %s with params: %s", query, params)
        
        if LOCAL_MODE:
            conn = sqlite3.connect(SQLITE_PATH)
            try:
                cur = conn.cursor()
                cur.execute(query, params)
                rows = cur.fetchall()
                
                results = []
                for row in rows:
                    # Convert datetime to ISO format string if it's a datetime object
                    time_value = row[1]
                    if time_value and hasattr(time_value, 'isoformat'):
                        time_value = time_value.isoformat()
                    elif time_value:
                        time_value = str(time_value)
                    
                    results.append({
                        'id': row[0],
                        'time': time_value,
                        'licensePlate': row[2],
                        'color': row[3],
                        'make': row[4],
                        'model': row[5]
                    })
                
                logging.info("Found %d results", len(results))
                return jsonify(results)
            finally:
                conn.close()
        else:
            # MySQL implementation
            connection = pymysql.connect(**DATABASE_CONFIG)
            try:
                with connection.cursor() as cursor:
                    cursor.execute(query, params)
                    rows = cursor.fetchall()
                    
                    results = []
                    for row in rows:
                        # Convert datetime to ISO format string if it's a datetime object
                        time_value = row[1]
                        if time_value and hasattr(time_value, 'isoformat'):
                            time_value = time_value.isoformat()
                        elif time_value:
                            time_value = str(time_value)
                        
                        results.append({
                            'id': row[0],
                            'time': time_value,
                            'licensePlate': row[2],
                            'color': row[3],
                            'make': row[4],
                            'model': row[5]
                        })
                    
                    logging.info("Found %d results", len(results))
                    return jsonify(results)
            finally:
                connection.close()
                
    except Exception as e:
        logging.exception("Database query failed: %s", e)
        return jsonify({'error': f'Database query failed: {str(e)}'}), 500

@app.route('/api/autocomplete/<field>', methods=['GET'])
def get_autocomplete_options(field):
    """Get unique values for autocomplete from the database"""
    try:
        # Validate field name to prevent SQL injection
        allowed_fields = ['plate_number', 'color', 'make', 'model']
        if field not in allowed_fields:
            return jsonify({'error': 'Invalid field'}), 400
        
        if LOCAL_MODE:
            conn = sqlite3.connect(SQLITE_PATH)
            try:
                cur = conn.cursor()
                cur.execute(f"SELECT DISTINCT {field} FROM plates WHERE {field} IS NOT NULL AND {field} != '' ORDER BY {field}")
                rows = cur.fetchall()
                options = [row[0] for row in rows if row[0]]
                return jsonify(options)
            finally:
                conn.close()
        else:
            # MySQL implementation
            connection = pymysql.connect(**DATABASE_CONFIG)
            try:
                with connection.cursor() as cursor:
                    cursor.execute(f"SELECT DISTINCT {field} FROM plates WHERE {field} IS NOT NULL AND {field} != '' ORDER BY {field}")
                    rows = cursor.fetchall()
                    options = [row[0] for row in rows if row[0]]
                    return jsonify(options)
            finally:
                connection.close()
                
    except Exception as e:
        logging.exception("Autocomplete query failed: %s", e)
        return jsonify({'error': f'Autocomplete query failed: {str(e)}'}), 500

@app.route('/api/plates/<int:plate_id>', methods=['PUT'])
def update_plate(plate_id):
    """Update a specific plate record in the database"""
    try:
        data = request.get_json()
        license_plate = data.get('licensePlate')
        color = data.get('color')
        make = data.get('make')
        model = data.get('model')
        
        logging.info("Updating plate ID %d with data: %s", plate_id, data)
        
        if LOCAL_MODE:
            conn = sqlite3.connect(SQLITE_PATH)
            try:
                cur = conn.cursor()
                cur.execute(
                    "UPDATE plates SET plate_number = ?, color = ?, make = ?, model = ? WHERE id = ?",
                    (license_plate, color, make, model, plate_id)
                )
                if cur.rowcount == 0:
                    return jsonify({'error': 'Record not found'}), 404
                conn.commit()
                logging.info("Updated plate ID %d successfully", plate_id)
                return jsonify({'success': True, 'message': 'Record updated successfully'})
            finally:
                conn.close()
        else:
            # MySQL implementation
            connection = pymysql.connect(**DATABASE_CONFIG)
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "UPDATE plates SET plate_number = %s, color = %s, make = %s, model = %s WHERE id = %s",
                        (license_plate, color, make, model, plate_id)
                    )
                    if cursor.rowcount == 0:
                        return jsonify({'error': 'Record not found'}), 404
                connection.commit()
                logging.info("Updated plate ID %d successfully", plate_id)
                return jsonify({'success': True, 'message': 'Record updated successfully'})
            finally:
                connection.close()
                
    except Exception as e:
        logging.exception("Update failed for plate ID %d: %s", plate_id, e)
        return jsonify({'error': f'Update failed: {str(e)}'}), 500

def parse_plate(alpr_output: str) -> str:
    # Kept for backward compatibility; unused now as PlateService parses
    try:
        data = json.loads(alpr_output)
        results = data.get('results', [])
        if results:
            top = results[0]
            plate = top.get('plate')
            if plate:
                return plate
            candidates = top.get('candidates') or []
            if candidates:
                best = candidates[0].get('plate')
                if best:
                    return best
    except Exception:
        pass
    for line in alpr_output.splitlines():
        if line.lower().startswith('plate'):
            parts = line.split()
            if len(parts) >= 2:
                return parts[1]
    return 'UNKNOWN'

def save_to_db(plate, attrs):
    make = attrs.get('make')
    model = attrs.get('model')
    color = attrs.get('color')
    
    if LOCAL_MODE:
        conn = sqlite3.connect(SQLITE_PATH)
        try:
            cur = conn.cursor()
            # Insert with explicit UTC timestamp
            utc_timestamp = datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
            cur.execute(
                "INSERT INTO plates (timestamp, plate_number, color, make, model) VALUES (?, ?, ?, ?, ?)",
                (utc_timestamp, plate, color, make, model),
            )
            conn.commit()
            logging.info("Saved to local DB: plate=%s color=%s make=%s model=%s", plate, color, make, model)
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
            # Insert with explicit UTC timestamp
            utc_timestamp = datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
            sql = """
                INSERT INTO plates (timestamp, plate_number, color, make, model)
                VALUES (%s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (utc_timestamp, plate, color, make, model))
        connection.commit()
        logging.info("Saved to MySQL DB: plate=%s color=%s make=%s model=%s", plate, color, make, model)
    finally:
        connection.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)