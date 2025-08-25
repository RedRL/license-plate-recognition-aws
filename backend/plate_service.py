import os
from openalpr import Alpr

class PlateRecognizer:
    def __init__(self):
        is_local = os.environ.get("LOCAL_MODE", "false").lower() == "true"

        if is_local:
            # Windows paths for local testing
            conf_path = r"C:\OpenALPR\openalpr.conf"
            runtime_path = r"C:\OpenALPR\runtime_data"
            country = "us"
        else:
            # Linux paths for AWS production
            conf_path = "/etc/openalpr/openalpr.conf"
            runtime_path = "/usr/share/openalpr/runtime_data"
            country = "us"

        self.alpr = Alpr(country, conf_path, runtime_path)
        if not self.alpr.is_loaded():
            raise RuntimeError("Failed to load OpenALPR engine.")

    def recognize(self, image_path):
        results = self.alpr.recognize_file(image_path)
        output = []
        for plate in results.get('plates', []):
            output.append({
                'plate': plate.get('characters', ''),
                'confidence': plate.get('overall_confidence', 0)
            })
        return output

    def __del__(self):
        if self.alpr:
            self.alpr.unload()
