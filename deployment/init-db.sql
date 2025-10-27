-- Database initialization script for License Plate Recognition
-- This script creates the necessary tables in the RDS MySQL database

USE license_plates_db;

-- Drop table if exists to ensure clean state
DROP TABLE IF EXISTS plates;

-- Create plates table with all required columns
CREATE TABLE plates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    plate_number VARCHAR(20),
    color VARCHAR(50),
    make VARCHAR(100),
    model VARCHAR(100),
    INDEX idx_plate_number (plate_number),
    INDEX idx_timestamp (timestamp),
    INDEX idx_color (color),
    INDEX idx_make (make),
    INDEX idx_model (model)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Verify table creation
DESCRIBE plates;

-- Display success message
SELECT 'Database initialized successfully!' AS Status;


