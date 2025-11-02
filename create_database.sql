-- Connect to ChirpStack PostgreSQL
-- Database: chirpstack
-- User: chirpstack
-- Password: chirpstack

-- Create schema for positioning data
CREATE SCHEMA IF NOT EXISTS positioning;

-- Table for RSSI measurements
CREATE TABLE IF NOT EXISTS positioning.rssi_measurements (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sender_id VARCHAR(50),
    receiver_id VARCHAR(50),
    rssi_dbm INTEGER,
    snr_db INTEGER,
    message_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for calculated distances
CREATE TABLE IF NOT EXISTS positioning.distances (
    id SERIAL PRIMARY KEY,
    measurement_id INTEGER REFERENCES positioning.rssi_measurements(id),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sender_id VARCHAR(50),
    receiver_id VARCHAR(50),
    rssi_dbm INTEGER,
    distance_meters DECIMAL(10, 2),
    path_loss_exponent DECIMAL(3, 1),
    tx_power_dbm INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for tag positions (when you have 3+ anchors)
CREATE TABLE IF NOT EXISTS positioning.tag_positions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tag_id VARCHAR(50),
    x_coordinate DECIMAL(10, 2),
    y_coordinate DECIMAL(10, 2),
    z_coordinate DECIMAL(10, 2),
    accuracy_meters DECIMAL(10, 2),
    num_anchors INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for anchor/receiver positions
CREATE TABLE IF NOT EXISTS positioning.anchors (
    id SERIAL PRIMARY KEY,
    anchor_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100),
    x_coordinate DECIMAL(10, 2),
    y_coordinate DECIMAL(10, 2),
    z_coordinate DECIMAL(10, 2),
    description TEXT,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert your receiver as anchor
INSERT INTO positioning.anchors (anchor_id, name, x_coordinate, y_coordinate, z_coordinate, description)
VALUES ('receiver_01', 'Main Receiver', 0.0, 0.0, 1.5, 'Wio-E5 receiver on COM3')
ON CONFLICT (anchor_id) DO NOTHING;

-- Create indexes for performance
CREATE INDEX idx_rssi_timestamp ON positioning.rssi_measurements(timestamp);
CREATE INDEX idx_rssi_sender ON positioning.rssi_measurements(sender_id);
CREATE INDEX idx_distances_timestamp ON positioning.distances(timestamp);
CREATE INDEX idx_positions_timestamp ON positioning.tag_positions(timestamp);

-- Create view for latest measurements
CREATE OR REPLACE VIEW positioning.latest_measurements AS
SELECT 
    r.id,
    r.timestamp,
    r.sender_id,
    r.receiver_id,
    r.rssi_dbm,
    r.snr_db,
    d.distance_meters,
    a.name as receiver_name,
    a.x_coordinate as receiver_x,
    a.y_coordinate as receiver_y
FROM positioning.rssi_measurements r
LEFT JOIN positioning.distances d ON r.id = d.measurement_id
LEFT JOIN positioning.anchors a ON r.receiver_id = a.anchor_id
ORDER BY r.timestamp DESC
LIMIT 100;

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA positioning TO chirpstack;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA positioning TO chirpstack;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA positioning TO chirpstack;
