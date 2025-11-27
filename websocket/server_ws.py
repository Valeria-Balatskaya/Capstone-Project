"""
Central Server - WebSocket Approach
Runs on Mac - receives data via WebSocket and performs trilateration
Combines real-time streaming with web dashboard
"""

import json
import time
import math
import asyncio
import websockets
from datetime import datetime, timezone
from typing import Dict, List, Tuple, Set, Optional
from collections import defaultdict
import argparse
import logging
import http.server
import threading

try:
    import numpy as np
    from scipy.optimize import minimize
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False
    print("Warning: scipy not installed. Using fallback method.")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RSSIToDistance:
    """Convert RSSI to distance"""
    
    def __init__(self, rssi_at_1m: float = -40, path_loss_exponent: float = 2.5):
        self.rssi_at_1m = rssi_at_1m
        self.path_loss_exponent = path_loss_exponent
    
    def calculate(self, rssi: float) -> float:
        if rssi >= self.rssi_at_1m:
            return 1.0
        return 10 ** ((self.rssi_at_1m - rssi) / (10 * self.path_loss_exponent))


class Trilaterator:
    """2D Trilateration"""
    
    def __init__(self, rssi_converter: RSSIToDistance):
        self.rssi_converter = rssi_converter
    
    def trilaterate(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float]:
        if len(receivers) < 3:
            raise ValueError("Need at least 3 receivers")
        
        distances = [self.rssi_converter.calculate(rssi) for rssi in rssi_values]
        
        if not SCIPY_AVAILABLE:
            return self._weighted_centroid(receivers, rssi_values)
        
        init_x = sum(r["x"] for r in receivers) / len(receivers)
        init_y = sum(r["y"] for r in receivers) / len(receivers)
        
        def objective(point):
            x, y = point
            error = 0
            for i, receiver in enumerate(receivers):
                est_dist = math.sqrt((x - receiver["x"])**2 + (y - receiver["y"])**2)
                error += (est_dist - distances[i])**2
            return error
        
        result = minimize(objective, [init_x, init_y], method='L-BFGS-B')
        return result.x[0], result.x[1]
    
    def _weighted_centroid(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float]:
        weights = [10 ** (rssi / 10) for rssi in rssi_values]
        total = sum(weights)
        x = sum(r["x"] * w for r, w in zip(receivers, weights)) / total
        y = sum(r["y"] * w for r, w in zip(receivers, weights)) / total
        return x, y


class WebSocketServer:
    """WebSocket server for receiving data and broadcasting positions"""
    
    def __init__(self, host: str = "0.0.0.0", port: int = 8765,
                 time_window_ms: int = 500, min_receivers: int = 3):
        self.host = host
        self.port = port
        self.time_window_ms = time_window_ms
        self.min_receivers = min_receivers
        
        self.rssi_converter = RSSIToDistance()
        self.trilaterator = Trilaterator(self.rssi_converter)
        
        # Connected clients (receivers and dashboards)
        self.receivers: Set[websockets.WebSocketServerProtocol] = set()
        self.dashboards: Set[websockets.WebSocketServerProtocol] = set()
        
        # Data buffer
        self.reading_buffer: Dict[int, Dict[str, dict]] = defaultdict(dict)
        
        # Position smoothing
        self.position_history: List[Tuple[float, float]] = []
        self.max_history = 5
        
        # Latest state for dashboard
        self.latest_position = {"x": 0, "y": 0}
        self.receiver_states: Dict[str, dict] = {}
        
        # Stats
        self.messages_received = 0
        self.positions_calculated = 0
    
    async def handle_client(self, websocket: websockets.WebSocketServerProtocol, path: str):
        """Handle new WebSocket connection"""
        client_type = "receiver"
        
        # Determine client type from path
        if path == "/dashboard":
            self.dashboards.add(websocket)
            client_type = "dashboard"
            logger.info(f"Dashboard connected from {websocket.remote_address}")
            # Send current state
            await self.send_state_to_dashboard(websocket)
        else:
            self.receivers.add(websocket)
            logger.info(f"Receiver connected from {websocket.remote_address}")
        
        try:
            async for message in websocket:
                if client_type == "receiver":
                    await self.process_receiver_message(message)
        except websockets.ConnectionClosed:
            pass
        finally:
            if client_type == "dashboard":
                self.dashboards.discard(websocket)
                logger.info("Dashboard disconnected")
            else:
                self.receivers.discard(websocket)
                logger.info("Receiver disconnected")
    
    async def process_receiver_message(self, message: str):
        """Process message from receiver"""
        try:
            data = json.loads(message)
            self.messages_received += 1
            
            receiver_id = data.get("receiver_id")
            timestamp_ms = data.get("timestamp_ms", int(time.time() * 1000))
            
            if not receiver_id:
                return
            
            # Update receiver state
            self.receiver_states[receiver_id] = {
                "position": data.get("position", {"x": 0, "y": 0}),
                "rssi": data.get("rssi"),
                "last_seen": datetime.now(timezone.utc).isoformat()
            }
            
            # Buffer reading
            bucket = timestamp_ms // self.time_window_ms
            self.reading_buffer[bucket][receiver_id] = {
                "position": data.get("position", {"x": 0, "y": 0}),
                "rssi": data.get("rssi"),
                "snr": data.get("snr"),
                "timestamp_ms": timestamp_ms
            }
            
            # Check if we can compute position
            if len(self.reading_buffer[bucket]) >= self.min_receivers:
                await self.compute_and_broadcast(bucket)
            
            # Cleanup old buckets
            self.cleanup_old_buckets(bucket)
            
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    async def compute_and_broadcast(self, bucket: int):
        """Compute position and broadcast to dashboards"""
        readings = self.reading_buffer[bucket]
        
        receivers = []
        rssi_values = []
        receiver_ids = []
        
        for rid, data in readings.items():
            if data.get("rssi") is not None:
                receivers.append(data["position"])
                rssi_values.append(data["rssi"])
                receiver_ids.append(rid)
        
        if len(receivers) < self.min_receivers:
            return
        
        try:
            x, y = self.trilaterator.trilaterate(receivers, rssi_values)
            
            # Smooth
            self.position_history.append((x, y))
            if len(self.position_history) > self.max_history:
                self.position_history.pop(0)
            
            avg_x = sum(p[0] for p in self.position_history) / len(self.position_history)
            avg_y = sum(p[1] for p in self.position_history) / len(self.position_history)
            
            self.latest_position = {"x": round(avg_x, 2), "y": round(avg_y, 2)}
            self.positions_calculated += 1
            
            # Log
            print("\n" + "="*50)
            print(f"📍 TAG POSITION: X={avg_x:.2f}m, Y={avg_y:.2f}m")
            print("-"*50)
            for i, rid in enumerate(receiver_ids):
                dist = self.rssi_converter.calculate(rssi_values[i])
                print(f"  {rid}: RSSI={rssi_values[i]}dBm → {dist:.2f}m")
            print(f"  Messages: {self.messages_received}, Positions: {self.positions_calculated}")
            print("="*50)
            
            # Broadcast to dashboards
            await self.broadcast_position()
            
            # Clear bucket
            del self.reading_buffer[bucket]
            
        except Exception as e:
            logger.error(f"Trilateration failed: {e}")
    
    async def broadcast_position(self):
        """Send position update to all dashboards"""
        if not self.dashboards:
            return
        
        message = json.dumps({
            "type": "position",
            "position": self.latest_position,
            "receivers": self.receiver_states,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "stats": {
                "messages": self.messages_received,
                "positions": self.positions_calculated
            }
        })
        
        # Send to all dashboards
        await asyncio.gather(
            *[ws.send(message) for ws in self.dashboards],
            return_exceptions=True
        )
    
    async def send_state_to_dashboard(self, websocket):
        """Send current state to newly connected dashboard"""
        message = json.dumps({
            "type": "init",
            "position": self.latest_position,
            "receivers": self.receiver_states
        })
        await websocket.send(message)
    
    def cleanup_old_buckets(self, current_bucket: int):
        """Remove old time buckets"""
        old = [b for b in self.reading_buffer.keys() if b < current_bucket - 10]
        for bucket in old:
            del self.reading_buffer[bucket]
    
    def calibrate(self, rssi_at_1m: float, path_loss: float):
        """Update calibration"""
        self.rssi_converter.rssi_at_1m = rssi_at_1m
        self.rssi_converter.path_loss_exponent = path_loss
        logger.info(f"Calibration: RSSI@1m={rssi_at_1m}, n={path_loss}")
    
    async def run(self):
        """Start the server"""
        server = await websockets.serve(
            self.handle_client,
            self.host,
            self.port,
            ping_interval=20,
            ping_timeout=10
        )
        
        logger.info(f"WebSocket server running on ws://{self.host}:{self.port}")
        logger.info(f"Dashboard endpoint: ws://{self.host}:{self.port}/dashboard")
        logger.info("Waiting for receivers...")
        
        await server.wait_closed()


def main():
    parser = argparse.ArgumentParser(description='WebSocket Server - Trilateration')
    parser.add_argument('--host', default='0.0.0.0', help='Bind address')
    parser.add_argument('--port', type=int, default=8765, help='WebSocket port')
    parser.add_argument('--time-window', type=int, default=500, help='Time window (ms)')
    parser.add_argument('--min-receivers', type=int, default=3, help='Minimum receivers')
    parser.add_argument('--rssi-1m', type=float, default=-40, help='RSSI at 1 meter')
    parser.add_argument('--path-loss', type=float, default=2.5, help='Path loss exponent')
    
    args = parser.parse_args()
    
    server = WebSocketServer(
        host=args.host,
        port=args.port,
        time_window_ms=args.time_window,
        min_receivers=args.min_receivers
    )
    server.calibrate(args.rssi_1m, args.path_loss)
    
    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        logger.info("Shutting down...")


if __name__ == "__main__":
    main()
