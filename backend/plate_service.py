import os
import json
import time
import shutil
import subprocess
import logging
from typing import Any, Dict, Optional


class PlateService:
    def __init__(self):
        self.local_mode = os.environ.get('LOCAL_MODE', 'false').lower() == 'true'
        self.country = os.environ.get('ALPR_COUNTRY', 'eu')

        # Resolve alpr binary and config similar to the current app logic
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        bundled_dir = os.path.join(repo_root, 'OpenALPR', 'openalpr-2.3.0-win-64bit', 'openalpr_64')

        alpr_bin = shutil.which('alpr')
        bundled_alpr = os.path.join(bundled_dir, 'alpr.exe')
        if not alpr_bin and os.path.exists(bundled_alpr):
            alpr_bin = bundled_alpr

        conf_path = os.environ.get('OPENALPR_CONFIG_FILE')
        if not conf_path:
            bundled_conf = os.path.join(bundled_dir, 'openalpr.conf')
            if os.path.exists(bundled_conf):
                conf_path = bundled_conf

        self.alpr_path = alpr_bin
        self.config_file = conf_path
        self.bundled_dir_exists = os.path.isdir(bundled_dir)

        logging.info(
            "[PlateService] Initialized: alpr_path=%s config_file=%s country=%s bundled_dir_exists=%s",
            self.alpr_path,
            self.config_file,
            self.country,
            self.bundled_dir_exists,
        )

    def recognize(self, image_path: str, timeout_seconds: int = 20) -> Dict[str, Any]:
        if not self.alpr_path:
            raise FileNotFoundError('alpr binary not found on PATH or bundled directory')

        alpr_args = [self.alpr_path, '-j', '-n', '5', '-c', self.country, image_path]
        logging.info("[PlateService] Invoking ALPR: %s", ' '.join(alpr_args))

        env = os.environ.copy()
        if self.config_file:
            env['OPENALPR_CONFIG_FILE'] = self.config_file

        t0 = time.time()
        proc = subprocess.run(alpr_args, text=True, capture_output=True, timeout=timeout_seconds, env=env)
        duration_ms = int((time.time() - t0) * 1000)
        logging.info("[PlateService] ALPR finished in %sms with rc=%s", duration_ms, proc.returncode)

        results_list: Optional[list] = None
        try:
            data = json.loads(proc.stdout)
            results_list = data.get('results', [])
        except Exception:
            results_list = None

        plate_string = self.parse_plate(proc.stdout)

        return {
            'return_code': proc.returncode,
            'stdout': proc.stdout,
            'stderr': proc.stderr,
            'duration_ms': duration_ms,
            'alpr_path': self.alpr_path,
            'config_file': self.config_file,
            'country': self.country,
            'results': results_list,
            'plate': plate_string,
        }

    def parse_plate(self, alpr_output: str) -> str:
        # Prefer JSON parsing (alpr -j) for reliable extraction
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

        # Fallback: legacy text parsing if JSON not available
        for line in alpr_output.splitlines():
            if line.lower().startswith('plate'):
                parts = line.split()
                if len(parts) >= 2:
                    return parts[1]
        return 'UNKNOWN'
