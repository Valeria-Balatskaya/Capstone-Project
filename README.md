[README.md](https://github.com/user-attachments/files/23291502/README.md)
# ChirpStack Server Setup Guide

This folder contains the ChirpStack server configuration and setup files for the Capstone Project.

## About ChirpStack

ChirpStack is an open-source LoRaWAN Network Server that enables you to set up and manage LoRaWAN networks. It provides a web interface for managing gateways, devices, and tenants, along with data integrations for major cloud providers and services.

## Prerequisites

Before installing ChirpStack, ensure you have the following components:

- **PostgreSQL** - Database for storing network data
- **Redis** - For caching and session management
- **Mosquitto** - MQTT broker for gateway communication
- **Docker and Docker Compose** (for Docker-based installation)
- **Operating System**: Ubuntu (latest LTS) or Debian (latest stable) recommended

## Installation Methods

### Option 1: Docker Installation (Recommended for Quick Setup)

Docker provides the fastest way to get ChirpStack running locally or on a VM.

#### Step 1: Install Docker

Verify Docker installation by running:
```bash
docker --version
```

#### Step 2: Clone the ChirpStack Docker Repository

```bash
git clone https://github.com/chirpstack/chirpstack-docker.git
cd chirpstack-docker
```

#### Step 3: Start ChirpStack

```bash
docker-compose up
```

On Windows, click "Share it" on any security popups. Wait until the logging stops, then access the web interface at `http://localhost:8080`.

**Default Login Credentials:**
- Username: `admin`
- Password: `admin`

### Option 2: Debian/Ubuntu Installation

#### Step 1: Install Required Services

```bash
sudo apt install \
  mosquitto \
  mosquitto-clients \
  redis-server \
  redis-tools \
  postgresql
```

#### Step 2: Configure PostgreSQL Database

Enter the PostgreSQL command line:
```bash
sudo -u postgres psql
```

Execute these commands inside the PostgreSQL prompt:
```sql
-- Create role for authentication
create role chirpstack with login password 'chirpstack';

-- Create database
create database chirpstack with owner chirpstack;

-- Change to chirpstack database
\c chirpstack

-- Create pg_trgm extension
create extension pg_trgm;

-- Exit
\q
```

Verify the database setup:
```bash
psql -h localhost -U chirpstack -W chirpstack
```

#### Step 3: Setup ChirpStack Repository

Install GPG:
```bash
sudo apt install gpg
```

Add the ChirpStack repository key:
```bash
sudo mkdir -p /etc/apt/keyrings/
sudo sh -c 'wget -q -O - https://artifacts.chirpstack.io/packages/chirpstack.key | gpg --dearmor > /etc/apt/keyrings/chirpstack.gpg'
```

Add the repository:
```bash
echo "deb [signed-by=/etc/apt/keyrings/chirpstack.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list
```

Update package cache:
```bash
sudo apt update
```

#### Step 4: Install ChirpStack

```bash
sudo apt install chirpstack
```

#### Step 5: Install ChirpStack Gateway Bridge (Optional)

If managing gateways from the server:
```bash
sudo apt install chirpstack-gateway-bridge
```

## Configuration

### ChirpStack Configuration Files

Configuration files are located at `/etc/chirpstack/`. The main configuration file is `chirpstack.toml`, with additional region-specific files like `region_*.toml`.

To view all configuration options:
```bash
chirpstack --help
```

### Environment Variables

Configuration values can be substituted with environment variables:
```toml
[integration.mqtt]
server="tcp://$MQTT_BROKER_HOST:1883/"
json=true
```

### Gateway Bridge Configuration

Edit `/etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml` to match your region. For EU868:
```toml
[integration.mqtt]
event_topic_template="eu868/gateway/{{ .GatewayID }}/event/{{ .EventType }}"
command_topic_template="eu868/gateway/{{ .GatewayID }}/command/#"
```

## Starting Services

### For Debian/Ubuntu Installation

Start ChirpStack:
```bash
# Start service
sudo systemctl start chirpstack

# Enable on boot
sudo systemctl enable chirpstack
```

Start Gateway Bridge (if installed):
```bash
sudo systemctl start chirpstack-gateway-bridge
sudo systemctl enable chirpstack-gateway-bridge
```

View logs:
```bash
sudo journalctl -f -n 100 -u chirpstack
```

### For Docker Installation

Restart services after reboot:
```bash
docker-compose up
```

To run in background (detached mode):
```bash
docker-compose up -d
```

Stop services:
```bash
docker-compose down
```

## Accessing ChirpStack

Open your browser and navigate to:
- **Local installation**: `http://localhost:8080`
- **Remote server**: `http://<server-ip>:8080`

Login with username `admin` and password `admin`.

**Important:** Change the default password after first login for security.

## Network Configuration

For connecting gateways to your ChirpStack instance, ensure the following ports are open and accessible:
- **8080** - Web interface
- **1883** - MQTT (unencrypted)
- **8883** - MQTT over TLS (if configured)

Find your server IP address:
- **Linux**: `hostname -I`
- **macOS**: System Preferences → Network
- **Windows**: `ipconfig` (check IPv4 Address)

## Common Issues and Troubleshooting

### Service won't start
Check the logs for errors:
```bash
sudo journalctl -u chirpstack -n 50
```

### Can't connect to database
Verify PostgreSQL is running:
```bash
sudo systemctl status postgresql
```

Check database credentials in `/etc/chirpstack/chirpstack.toml`

### Gateway not connecting
1. Verify MQTT broker (Mosquitto) is running
2. Check gateway configuration points to correct server IP
3. Ensure firewall allows port 1883

### Web interface not accessible
1. Check if ChirpStack service is running: `sudo systemctl status chirpstack`
2. Verify port 8080 is not blocked by firewall
3. Try accessing via server IP instead of localhost

## Project Structure

```
chirpstack/
├── README.md                    # This file
├── configuration/               # Configuration files
│   └── chirpstack.toml         # Main configuration
├── docker-compose.yml          # Docker compose file (if using Docker)
└── scripts/                    # Helper scripts
```

## Downloads Required

### For Docker Installation:
- Docker: https://docs.docker.com/get-docker/
- Docker Compose: https://docs.docker.com/compose/install/

### For Native Installation:
- PostgreSQL: `sudo apt install postgresql`
- Redis: `sudo apt install redis-server`
- Mosquitto: `sudo apt install mosquitto`
- ChirpStack: From ChirpStack repository (see installation steps)

## Additional Resources

- **Official Documentation**: https://www.chirpstack.io/docs/
- **GitHub Repository**: https://github.com/chirpstack/chirpstack
- **Docker Images**: https://hub.docker.com/u/chirpstack
- **Community Forum**: https://forum.chirpstack.io/
- **Region Configurations**: https://github.com/chirpstack/chirpstack/tree/master/chirpstack/configuration

## API Documentation

ChirpStack provides a RESTful API for programmatic access. After installation, API documentation is available at:
- `http://localhost:8080/api`

## Next Steps

1. Install ChirpStack using your preferred method
2. Access the web interface and change default password
3. Configure your region settings
4. Add gateways to the network
5. Register devices and create applications
6. Set up integrations for data forwarding

## Support

For issues specific to this project:
- Project Repository: https://github.com/Valeria-Balatskaya/Capstone-Project/tree/chirpstack

For ChirpStack-related issues:
- ChirpStack Forum: https://forum.chirpstack.io/
- GitHub Issues: https://github.com/chirpstack/chirpstack/issues

## License

ChirpStack is distributed under the MIT license.

---

**Last Updated:** November 2025
