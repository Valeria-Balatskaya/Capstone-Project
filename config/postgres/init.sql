-- Enable required PostgreSQL extensions for ChirpStack
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS hstore;

-- Create positioning schema
CREATE SCHEMA IF NOT EXISTS lora_positioning;

-- Gateway reference data (static)
CREATE TABLE IF NOT EXISTS lora_positioning.gateways (
    gateway_id VARCHAR(16) PRIMARY KEY,
    gateway_name VARCHAR(100),
    gateway_eui VARCHAR(16),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    altitude DECIMAL(10, 2),
    antenna_height_m DECIMAL(5, 2),
    description TEXT,
    active BOOLEAN DEFAULT TRUE,
    installed_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Device reference data
CREATE TABLE IF NOT EXISTS lora_positioning.devices (
    device_id VARCHAR(16) PRIMARY KEY,
    device_name VARCHAR(100),
    device_eui VARCHAR(16),
    device_type VARCHAR(50),
    description TEXT,
    active BOOLEAN DEFAULT TRUE,
    tx_power_dbm INTEGER DEFAULT -20,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Experiments metadata
CREATE TABLE IF NOT EXISTS lora_positioning.experiments (
    experiment_id SERIAL PRIMARY KEY,
    experiment_name VARCHAR(200),
    description TEXT,
    test_type VARCHAR(50),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    building_floor INT,
    environmental_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ground truth positions for validation
CREATE TABLE IF NOT EXISTS lora_positioning.ground_truth (
    gt_id SERIAL PRIMARY KEY,
    experiment_id INT REFERENCES lora_positioning.experiments(experiment_id),
    device_id VARCHAR(16) REFERENCES lora_positioning.devices(device_id),
    timestamp TIMESTAMP,
    true_x DECIMAL(10, 2),
    true_y DECIMAL(10, 2),
    true_z DECIMAL(10, 2),
    collection_method VARCHAR(50),
    confidence_level VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Position history (for analysis)
CREATE TABLE IF NOT EXISTS lora_positioning.position_history (
    pos_id SERIAL PRIMARY KEY,
    experiment_id INT REFERENCES lora_positioning.experiments(experiment_id),
    device_id VARCHAR(16),
    timestamp TIMESTAMP,
    estimated_x DECIMAL(10, 2),
    estimated_y DECIMAL(10, 2),
    estimated_z DECIMAL(10, 2),
    error_meters DECIMAL(8, 2),
    num_gateways INT,
    raw_rssi_values TEXT,
    algorithm VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Performance metrics
CREATE TABLE IF NOT EXISTS lora_positioning.performance_metrics (
    metric_id SERIAL PRIMARY KEY,
    experiment_id INT REFERENCES lora_positioning.experiments(experiment_id),
    timestamp TIMESTAMP,
    rmse_meters DECIMAL(8, 2),
    median_error_meters DECIMAL(8, 2),
    max_error_meters DECIMAL(8, 2),
    prr_percent DECIMAL(5, 2),
    latency_seconds DECIMAL(6, 3),
    num_samples INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_experiments_time ON lora_positioning.experiments(start_time);
CREATE INDEX idx_ground_truth_exp ON lora_positioning.ground_truth(experiment_id);
CREATE INDEX idx_metrics_exp ON lora_positioning.performance_metrics(experiment_id);
CREATE INDEX idx_position_history_time ON lora_positioning.position_history(timestamp);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA lora_positioning TO chirpstack;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA lora_positioning TO chirpstack;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA lora_positioning TO chirpstack;
