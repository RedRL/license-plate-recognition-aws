import os
import json
import logging
from typing import Dict, Optional, Tuple

import cv2
import numpy as np


class VehicleAttributesService:
    def __init__(self):
        # Focus only on what we can actually do accurately
        pass

    def analyze(self, image_path: str) -> Dict[str, Optional[str]]:
        image = cv2.imread(image_path)
        if image is None:
            attrs = {"make": None, "model": None, "color": None}
            logging.info("VehicleAttributesService.analyze: path=%s attrs=%s (image read failed)", image_path, attrs)
            return attrs

        # Only detect color - be honest about make/model limitations
        color = self._detect_color_accurately(image)

        attrs = {
            "make": None,  # Honest: we can't reliably detect this
            "model": None,  # Honest: we can't reliably detect this
            "color": color,
        }
        logging.info("VehicleAttributesService.analyze: path=%s attrs=%s", image_path, attrs)
        return attrs

    def _detect_color_accurately(self, image: np.ndarray) -> str:
        """Highly accurate color detection using multiple proven techniques"""
        try:
            # Preprocess image for better color analysis
            processed_image = self._preprocess_for_color(image)
            
            # Convert to HSV color space (better for color analysis)
            hsv = cv2.cvtColor(processed_image, cv2.COLOR_BGR2HSV)
            
            # Get multiple color samples from different vehicle regions
            color_samples = self._get_color_samples(hsv)
            
            if not color_samples:
                return self._analyze_brightness_fallback(hsv)
            
            # Analyze each sample and vote on color
            color_votes = {}
            black_white_votes = 0
            total_samples = len(color_samples)
            
            for sample in color_samples:
                sample_color = self._analyze_color_sample(sample)
                if sample_color != 'unknown':
                    color_votes[sample_color] = color_votes.get(sample_color, 0) + 1
                    # Track black/white specifically
                    if sample_color in ['black', 'white']:
                        black_white_votes += 1
            
            # Special handling for black/white: if ANY samples detect black/white, prioritize them
            if color_votes:
                logging.info(f"Raw votes before black/white priority: {color_votes}")
                
                # If we have significant black or white votes, prioritize them
                black_votes = color_votes.get('black', 0)
                white_votes = color_votes.get('white', 0)
                
                # Handle black/white priority and tie-breaking
                black_threshold = max(1, total_samples * 0.5)  # 50% for black
                white_threshold = max(2, total_samples * 0.6)  # 60% for white (more conservative)
                
                if black_votes >= black_threshold:
                    logging.info(f"BLACK PRIORITY: {black_votes}/{total_samples} samples detected black")
                    return "black"
                elif white_votes >= white_threshold:
                    logging.info(f"WHITE PRIORITY: {white_votes}/{total_samples} samples detected white")
                    return "white"
                elif black_votes > 0 and white_votes > 0:
                    # Handle any black/white competition before going to fallback
                    if black_votes == white_votes:
                        # Tie-breaking: use overall image brightness to decide (favor white for brighter images)
                        logging.info(f"BLACK/WHITE TIE: {black_votes} each, using brightness to decide")
                        overall_brightness = np.mean(hsv[:, :, 2])
                        if overall_brightness < 100:  # Lower threshold - prefer white unless clearly dark
                            logging.info(f"TIE-BREAKER: Choosing BLACK (overall brightness: {overall_brightness:.1f})")
                            return "black"
                        else:
                            logging.info(f"TIE-BREAKER: Choosing WHITE (overall brightness: {overall_brightness:.1f})")
                            return "white"
                    elif black_votes > white_votes and black_votes >= total_samples * 0.3:
                        logging.info(f"BLACK PREFERENCE: {black_votes}/{total_samples} vs white {white_votes}")
                        return "black"
                    elif white_votes > black_votes and white_votes >= total_samples * 0.3:
                        logging.info(f"WHITE PREFERENCE: {white_votes}/{total_samples} vs black {black_votes}")
                        return "white"
                
                # Smart voting with color context awareness
                sorted_colors = sorted(color_votes.items(), key=lambda x: x[1], reverse=True)
                best_color, best_votes = sorted_colors[0]
                total_votes = sum(color_votes.values())
                
                # Check for color confusion patterns and resolve intelligently
                if len(sorted_colors) >= 2:
                    second_color, second_votes = sorted_colors[1]
                    
                    # Blue confusion resolution: Blue often comes from reflections/shadows
                    if best_color == "blue":
                        # Orange vs Blue confusion - be more aggressive for orange
                        if "orange" in color_votes:
                            orange_votes = color_votes["orange"]
                            # Any orange presence suggests orange car (orange less likely to be false positive)
                            if orange_votes >= 1:
                                logging.info(f"ORANGE over BLUE: Any orange detected overrides blue - orange {orange_votes}/{total_votes} votes")
                                logging.info(f"Color detection: orange (orange priority, votes: {color_votes})")
                                return "orange"
                        
                        # White vs Blue confusion: only override blue if achromatic evidence is STRONG
                        white_votes = color_votes.get("white", 0)
                        black_votes = color_votes.get("black", 0)
                        achromatic_votes = white_votes + black_votes
                        
                        # Only override blue if achromatic votes are substantial AND no orange present
                        if (achromatic_votes >= total_votes * 0.4 and  # Raised from 30% to 40%
                            "orange" not in color_votes and  # Don't interfere with orange detection
                            best_votes >= total_votes * 0.7):  # Only for overwhelming blue votes (4/5+)
                            
                            logging.info(f"ACHROMATIC over BLUE: {achromatic_votes}/{total_votes} achromatic votes, overwhelming blue {best_votes}/{total_votes}")
                            if white_votes >= black_votes:
                                logging.info(f"Color detection: white (strong achromatic preference, votes: {color_votes})")
                                return "white"
                            else:
                                logging.info(f"Color detection: black (strong achromatic preference, votes: {color_votes})")
                                return "black"
                    
                    # Similar logic for other common confusions could be added here
                
                # Standard confidence-based voting
                confidence = best_votes / total_votes
                if confidence >= 0.5:
                    logging.info(f"Color detection: {best_color} (confidence: {confidence:.2f}, votes: {color_votes})")
                    return best_color
                else:
                    logging.info(f"Low confidence color detection: {color_votes}, using fallback")
            
            # Fallback to brightness analysis
            return self._analyze_brightness_fallback(hsv)
            
        except Exception as e:
            logging.error(f"Color detection failed: {e}")
            return "unknown"

    def _preprocess_for_color(self, image: np.ndarray) -> np.ndarray:
        """Preprocess image to improve color detection accuracy"""
        # Resize to reasonable size for processing
        height, width = image.shape[:2]
        if max(height, width) > 400:
            scale = 400 / max(height, width)
            new_h, new_w = int(height * scale), int(width * scale)
            image = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_AREA)
        
        # Apply gentle bilateral filter to reduce noise while preserving edges
        filtered = cv2.bilateralFilter(image, 9, 80, 80)
        
        return filtered

    def _get_color_samples(self, hsv: np.ndarray) -> list:
        """Extract color samples from multiple vehicle regions"""
        h, w = hsv.shape[:2]
        samples = []
        
        # Define regions where vehicle color is most likely to be visible
        regions = [
            # Main body center
            (h//3, 2*h//3, w//3, 2*w//3),
            # Left side panel
            (h//4, 3*h//4, w//8, w//2),
            # Right side panel  
            (h//4, 3*h//4, w//2, 7*w//8),
            # Upper body (hood/roof area)
            (h//6, h//2, w//4, 3*w//4),
            # Lower body (doors area)
            (h//2, 5*h//6, w//4, 3*w//4)
        ]
        
        for y1, y2, x1, x2 in regions:
            # Ensure coordinates are valid
            y1, y2 = max(0, y1), min(h, y2)
            x1, x2 = max(0, x1), min(w, x2)
            
            if y2 > y1 and x2 > x1:
                region = hsv[y1:y2, x1:x2]
                if region.size > 50:  # Ensure minimum region size
                    samples.append(region)
        
        return samples

    def _analyze_color_sample(self, sample: np.ndarray) -> str:
        """Analyze a single color sample and return the dominant color"""
        try:
            # Extract HSV channels
            h_values = sample[:, :, 0].flatten()
            s_values = sample[:, :, 1].flatten()
            v_values = sample[:, :, 2].flatten()
            
            # Calculate overall statistics first
            mean_brightness = np.mean(v_values)
            mean_saturation = np.mean(s_values)
            median_brightness = np.median(v_values)
            median_saturation = np.median(s_values)
            
            # Log the values we're seeing for debugging
            logging.info(f"Sample stats: brightness_mean={mean_brightness:.1f}, brightness_median={median_brightness:.1f}, saturation_mean={mean_saturation:.1f}, saturation_median={median_saturation:.1f}")
            
            # Much more aggressive black detection
            if mean_brightness < 85 or median_brightness < 90:
                logging.info(f"Detected BLACK: brightness_mean={mean_brightness:.1f}, median={median_brightness:.1f}")
                return "black"
            
            # More precise white detection (avoid false positives on bright colored cars)
            if (mean_brightness > 150 and mean_saturation < 60) or \
               (median_brightness > 160 and median_saturation < 50) or \
               (mean_brightness > 140 and mean_saturation < 35):
                logging.info(f"Detected WHITE: brightness_mean={mean_brightness:.1f}, saturation_mean={mean_saturation:.1f}")
                return "white"
            
            # Filter out pixels for color analysis (but keep more pixels)
            valid_mask = (s_values > 20) & (v_values > 40) & (v_values < 200)
            
            if np.sum(valid_mask) < 10:
                # Very few valid colored pixels - definitely achromatic
                if mean_brightness < 100:
                    return "black"
                elif mean_brightness > 120:
                    return "white"
                else:
                    return "gray"
            
            # Analyze chromatic colors
            valid_h = h_values[valid_mask]
            valid_s = s_values[valid_mask]
            valid_v = v_values[valid_mask]
            
            mean_saturation_filtered = np.mean(valid_s)
            mean_brightness_filtered = np.mean(valid_v)
            
            # Even after filtering, check for low saturation (achromatic colors)
            if mean_saturation_filtered < 40:
                if mean_brightness_filtered < 85:
                    return "black"
                elif mean_brightness_filtered > 135:
                    return "white"
                elif mean_brightness_filtered < 115:
                    return "gray"
                else:
                    return "silver"
            
            # For chromatic colors, find the dominant hue using histogram
            hist, bin_edges = np.histogram(valid_h, bins=36, range=(0, 180))
            
            # Find the peak in the histogram
            dominant_bin = np.argmax(hist)
            dominant_hue = (bin_edges[dominant_bin] + bin_edges[dominant_bin + 1]) / 2
            
            # Convert OpenCV hue (0-180) to standard hue (0-360)
            hue_360 = dominant_hue * 2
            
            # Map hue to color names with careful boundaries
            color_result = self._hue_to_color_name(hue_360)
            logging.debug(f"Detected COLOR: {color_result} from hue={hue_360:.1f}")
            return color_result
            
        except Exception as e:
            logging.warning(f"Color sample analysis failed: {e}")
            return "unknown"

    def _hue_to_color_name(self, hue: float) -> str:
        """Convert hue value to color name with precise boundaries"""
        # Normalize hue to 0-360 range
        hue = hue % 360
        
        # Define color boundaries based on human perception
        if hue < 10 or hue >= 350:
            return "red"
        elif 10 <= hue < 35:
            return "orange"  # Orange range (reduced from 45 back to 35)
        elif 35 <= hue < 78:
            return "yellow"  # Yellow and yellow-green (expanded start)
        elif 78 <= hue < 142:
            return "green"
        elif 142 <= hue < 178:
            return "cyan"  # Blue-green
        elif 178 <= hue < 248:
            return "blue"
        elif 248 <= hue < 282:
            return "blue"  # Blue-purple, often seen as blue
        elif 282 <= hue < 318:
            return "purple"
        elif 318 <= hue < 352:
            return "pink"  # Purple-red
        else:
            return "unknown"

    def _analyze_brightness_fallback(self, hsv: np.ndarray) -> str:
        """Fallback color analysis based on brightness when color detection fails"""
        try:
            # Focus on center region for fallback analysis
            h, w = hsv.shape[:2]
            center_region = hsv[h//4:3*h//4, w//4:3*w//4]
            
            if center_region.size == 0:
                center_region = hsv
            
            # Analyze brightness distribution
            v_channel = center_region[:, :, 2]
            s_channel = center_region[:, :, 1]
            
            mean_brightness = np.mean(v_channel)
            mean_saturation = np.mean(s_channel)
            median_brightness = np.median(v_channel)
            median_saturation = np.median(s_channel)
            
            logging.debug(f"Fallback stats: brightness_mean={mean_brightness:.1f}, brightness_median={median_brightness:.1f}, saturation_mean={mean_saturation:.1f}")
            
            # Very aggressive black/white detection for fallback
            if mean_brightness < 90 or median_brightness < 95:
                logging.info(f"Fallback detected BLACK")
                return "black"
            elif (mean_brightness > 135 and mean_saturation < 70) or \
                 (median_brightness > 140 and median_saturation < 60):
                logging.info(f"Fallback detected WHITE")
                return "white"
            elif mean_saturation < 25:  # Very low saturation
                if mean_brightness < 105:
                    return "gray"
                else:
                    return "silver"
            else:
                # Some color present but unclear - make best guess from hue
                h_channel = center_region[:, :, 0]
                # Filter by saturation and brightness
                valid_pixels = (s_channel > 15) & (v_channel > 35) & (v_channel < 210)
                
                if np.sum(valid_pixels) > 5:
                    valid_hues = h_channel[valid_pixels]
                    median_hue = np.median(valid_hues) * 2  # Convert to 0-360
                    result = self._hue_to_color_name(median_hue)
                    logging.debug(f"Fallback color from hue: {result}")
                    return result
                else:
                    return "gray"  # Can't determine color
            
        except Exception as e:
            logging.warning(f"Brightness fallback analysis failed: {e}")
            return "unknown" 