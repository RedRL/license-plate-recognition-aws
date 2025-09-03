import cv2
import numpy as np
from typing import Dict, Optional
import logging


class VehicleAttributesService:
    def __init__(self):
        pass

    def analyze(self, image_path: str) -> Dict[str, Optional[str]]:
        # Read image (BGR)
        image = cv2.imread(image_path)
        if image is None:
            attrs = {"make": None, "model": None, "color": None}
            logging.info("VehicleAttributesService.analyze: path=%s attrs=%s (image read failed)", image_path, attrs)
            return attrs

        # Resize to manageable size for stable statistics
        max_dim = 640
        h, w = image.shape[:2]
        scale = min(1.0, float(max_dim) / float(max(h, w)))
        if scale < 1.0:
            image = cv2.resize(image, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

        # Convert to HSV for color analysis
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        h_chan, s_chan, v_chan = cv2.split(hsv)

        # Heuristic mask to down-weight background extremes: ignore very dark or very bright pixels
        mask = (v_chan > 30) & (v_chan < 230)
        mask = mask & (s_chan > 25)  # avoid near-gray/white noise

        if np.count_nonzero(mask) < 1000:
            # Fallback to whole image if mask too small
            mask = np.ones(h_chan.shape, dtype=bool)

        # Compute dominant hue histogram on masked pixels
        hues = h_chan[mask]
        sats = s_chan[mask]
        vals = v_chan[mask]

        # If very low saturation on average, classify as gray-scale colors
        mean_sat = float(np.mean(sats)) if hues.size > 0 else 0.0
        mean_val = float(np.mean(vals)) if vals.size > 0 else 0.0

        if mean_sat < 35:
            if mean_val < 60:
                color_name = "black"
            elif mean_val > 200:
                color_name = "white"
            else:
                color_name = "gray"
        else:
            # 180 bins for OpenCV hue range [0,179]
            hist = cv2.calcHist([hues], [0], None, [36], [0, 180])
            dominant_bin = int(np.argmax(hist))
            hue_center = (dominant_bin + 0.5) * (180.0 / 36.0)
            color_name = self._hue_to_color(hue_center)

        # Make/model are placeholders for now (free offline models can be integrated later)
        attrs = {
            "make": None,
            "model": None,
            "color": color_name,
        }
        logging.info("VehicleAttributesService.analyze: path=%s attrs=%s", image_path, attrs)
        return attrs

    def _hue_to_color(self, hue_deg: float) -> str:
        # Map hue (0-180 OpenCV scale mapped to 0-360) to common color names
        # Convert to 0-360 range for readability
        hue = (hue_deg / 180.0) * 360.0
        if hue < 15 or hue >= 345:
            return "red"
        if 15 <= hue < 35:
            return "orange"
        if 35 <= hue < 65:
            return "yellow"
        if 65 <= hue < 170:
            return "green"
        if 170 <= hue < 200:
            return "cyan"
        if 200 <= hue < 255:
            return "blue"
        if 255 <= hue < 290:
            return "purple"
        if 290 <= hue < 345:
            return "pink"
        return "unknown" 