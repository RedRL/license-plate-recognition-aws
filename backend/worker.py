#!/usr/bin/env python3
"""
SQS Worker for License Plate Recognition
Continuously polls SQS queue, downloads images from S3, runs ALPR + color detection,
and saves results to the database.

Usage:
    python worker.py
"""

import os
import sys
import time
import json
import logging
import signal
import boto3
import pymysql
import datetime
from botocore.exceptions import ClientError
from logging.handlers import RotatingFileHandler
from plate_service import PlateService
from vehicle_attributes_service import VehicleAttributesService

# ============================================================================
# Configuration
# ============================================================================

AWS_REGION = os.getenv('AWS_REGION', 'eu-central-1')
S3_BUCKET = os.getenv('S3_BUCKET', 'license-plates-images-bucket')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL', '')
LOCAL_MODE = os.getenv('LOCAL_MODE', 'false').lower() == 'true'
WORKER_POLL_INTERVAL = int(os.getenv('WORKER_POLL_INTERVAL', '20'))  # Long polling seconds
WORKER_MAX_MESSAGES = int(os.getenv('WORKER_MAX_MESSAGES', '1'))  # Process 1 at a time
VISIBILITY_TIMEOUT = int(os.getenv('VISIBILITY_TIMEOUT', '60'))  # Seconds

# Database configuration
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_USER = os.getenv('DB_USER', 'root')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'root')
DB_NAME = os.getenv('DB_NAME', 'license_plates_db')

DATABASE_CONFIG = {
    'host': DB_HOST,
    'user': DB_USER,
    'password': DB_PASSWORD,
    'database': DB_NAME
}

# Logging configuration
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO').upper()
numeric_level = getattr(logging, LOG_LEVEL, logging.INFO)
LOG_FILE = os.getenv('WORKER_LOG_FILE', os.path.join(os.path.dirname(__file__), 'logs', 'worker.log'))
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

root_logger = logging.getLogger()
root_logger.handlers.clear()
root_logger.setLevel(numeric_level)

formatter = logging.Formatter('[%(asctime)s] %(levelname)s [Worker] %(message)s')

# Console handler
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(numeric_level)
console_handler.setFormatter(formatter)
root_logger.addHandler(console_handler)

# File handler - disabled, systemd handles logging via StandardOutput/Error
# file_handler = RotatingFileHandler(LOG_FILE, maxBytes=10*1024*1024, backupCount=5, encoding='utf-8')
# file_handler.setLevel(numeric_level)
# file_handler.setFormatter(formatter)
# root_logger.addHandler(file_handler)

# ============================================================================
# Global state
# ============================================================================

running = True
sqs_client = None if LOCAL_MODE else boto3.client('sqs', region_name=AWS_REGION)
s3_client = None if LOCAL_MODE else boto3.client('s3', region_name=AWS_REGION)
plate_service = PlateService()
vehicle_attr_service = VehicleAttributesService()

# ============================================================================
# Signal handling for graceful shutdown
# ============================================================================

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global running
    logging.info(f"Received signal {signum}, shutting down gracefully...")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# ============================================================================
# Database functions
# ============================================================================

def get_db_connection():
    """Get database connection"""
    try:
        return pymysql.connect(**DATABASE_CONFIG)
    except Exception as e:
        logging.error(f"Failed to connect to database: {e}")
        return None

def save_to_db(plate, attrs):
    """Save recognition results to database"""
    conn = get_db_connection()
    if not conn:
        return False
    
    try:
        with conn.cursor() as cursor:
            # Use UTC timestamp to match database expectation
            utc_timestamp = datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
            cursor.execute("""
                INSERT INTO plates (plate_number, color, make, model, timestamp)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                plate,
                attrs.get('color'),
                attrs.get('make'),
                attrs.get('model'),
                utc_timestamp
            ))
            conn.commit()
            logging.info(f"Saved to database: plate={plate}, make={attrs.get('make')}, model={attrs.get('model')}, color={attrs.get('color')}")
            return True
    except Exception as e:
        logging.error(f"Failed to save to database: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

# ============================================================================
# SQS processing functions
# ============================================================================

def download_image_from_s3(image_key, local_path):
    """Download image from S3 to local path"""
    try:
        s3_client.download_file(S3_BUCKET, image_key, local_path)
        logging.info(f"Downloaded image from S3: {image_key} -> {local_path}")
        return True
    except ClientError as e:
        logging.error(f"Failed to download image from S3: {e}")
        return False

def process_message(message):
    """Process a single SQS message"""
    try:
        # Parse message body
        message_body = json.loads(message['Body'])
        image_key = message_body['image_key']
        timestamp = message_body['timestamp']
        
        logging.info(f"Processing message: image_key={image_key}, timestamp={timestamp}")
        
        # Download image from S3
        local_path = f"/tmp/{image_key}"
        if not download_image_from_s3(image_key, local_path):
            logging.error(f"Failed to download image: {image_key}")
            return False
        
        # Process image with ALPR
        try:
            result = plate_service.recognize(local_path, timeout_seconds=30)
            if result['return_code'] != 0:
                logging.error(f"ALPR error: rc={result['return_code']}, stderr={result['stderr']}")
                return False
            
            plate = result['plate']
            logging.info(f"ALPR result: plate={plate}")
            
        except Exception as e:
            logging.error(f"ALPR processing failed: {e}")
            return False
        
        # Analyze vehicle attributes
        try:
            attrs = vehicle_attr_service.analyze(local_path)
            logging.info(f"Vehicle attributes: make={attrs.get('make')}, model={attrs.get('model')}, color={attrs.get('color')}")
        except Exception as e:
            logging.error(f"Vehicle attribute analysis failed: {e}")
            attrs = {}
        
        # Save to database
        if not save_to_db(plate, attrs):
            logging.error(f"Failed to save results to database")
            return False
        
        # Clean up local file
        try:
            os.remove(local_path)
        except Exception as e:
            logging.warning(f"Failed to remove local file {local_path}: {e}")
        
        logging.info(f"Successfully processed image: {image_key}")
        return True
        
    except Exception as e:
        logging.exception(f"Failed to process message: {e}")
        return False

def poll_sqs_queue():
    """Poll SQS queue for messages"""
    try:
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=WORKER_MAX_MESSAGES,
            WaitTimeSeconds=WORKER_POLL_INTERVAL,
            VisibilityTimeout=VISIBILITY_TIMEOUT
        )
        
        messages = response.get('Messages', [])
        logging.debug(f"Received {len(messages)} messages from SQS")
        
        for message in messages:
            try:
                # Process the message
                success = process_message(message)
                
                if success:
                    # Delete message from queue on success
                    sqs_client.delete_message(
                        QueueUrl=SQS_QUEUE_URL,
                        ReceiptHandle=message['ReceiptHandle']
                    )
                    logging.info(f"Deleted processed message from queue")
                else:
                    logging.error(f"Failed to process message, leaving in queue for retry")
                    
            except Exception as e:
                logging.exception(f"Error processing message: {e}")
                
    except ClientError as e:
        logging.error(f"SQS polling error: {e}")
    except Exception as e:
        logging.exception(f"Unexpected error in poll_sqs_queue: {e}")

# ============================================================================
# Main worker loop
# ============================================================================

def main():
    """Main worker loop"""
    logging.info("Starting SQS Worker for License Plate Recognition")
    logging.info(f"Configuration: AWS_REGION={AWS_REGION}, S3_BUCKET={S3_BUCKET}")
    logging.info(f"Queue URL: {SQS_QUEUE_URL}")
    logging.info(f"Poll interval: {WORKER_POLL_INTERVAL}s, Max messages: {WORKER_MAX_MESSAGES}")
    
    if LOCAL_MODE:
        logging.error("Worker cannot run in LOCAL_MODE")
        sys.exit(1)
    
    if not SQS_QUEUE_URL:
        logging.error("SQS_QUEUE_URL environment variable not set")
        sys.exit(1)
    
    # Test database connection
    conn = get_db_connection()
    if not conn:
        logging.error("Failed to connect to database, exiting")
        sys.exit(1)
    conn.close()
    
    logging.info("Worker started successfully, beginning message polling...")
    
    try:
        while running:
            poll_sqs_queue()
            time.sleep(1)  # Small delay between polling cycles
            
    except KeyboardInterrupt:
        logging.info("Received keyboard interrupt, shutting down...")
    except Exception as e:
        logging.exception(f"Unexpected error in main loop: {e}")
    finally:
        logging.info("Worker shutdown complete")

if __name__ == '__main__':
    main()