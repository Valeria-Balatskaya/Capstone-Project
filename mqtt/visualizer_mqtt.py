"""
Real-time Position Visualizer - MQTT Approach
Shows tag position on a 2D map with receiver locations
"""

import json
import threading
import paho.mqtt.client as mqtt
import argparse
import logging
from typing import Dict, List, Tuple

try:
    import matplotlib.pyplot as plt
    import matplotlib.animation as animation
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False
    print("Warning: matplotlib not installed. Install with: pip3 install matplotlib")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)


class PositionVisualizer:
    """Real-time 2D visualization of tag position"""
    
    def __init__(self, mqtt_host: str, mqtt_port: int = 1883,
                 room_width: float = 10, room_height: float = 10):
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.room_width = room_width
        self.room_height = room_height
        
        self.receivers: Dict[str, dict] = {}
        self.tag_position = {"x": room_width/2, "y": room_height/2}
        self.position_history: List[Tuple[float, float]] = []
        self.max_trail = 50
        
        self.mqtt_client = None
        self.lock = threading.Lock()
        
    def connect_mqtt(self):
        """Connect to MQTT broker"""
        self.mqtt_client = mqtt.Client(client_id="visualizer")
        self.mqtt_client.on_connect = self._on_connect
        self.mqtt_client.on_message = self._on_message
        
        self.mqtt_client.connect(self.mqtt_host, self.mqtt_port, keepalive=60)
        self.mqtt_client.loop_start()
    
    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            client.subscribe("lora/receivers", qos=1)
            client.subscribe("lora/position", qos=1)
            logger.info("Connected to MQTT, subscribed to topics")
    
    def _on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode('utf-8'))
            
            if msg.topic == "lora/receivers":
                receiver_id = data.get("receiver_id")
                if receiver_id and "position" in data:
                    with self.lock:
                        self.receivers[receiver_id] = data["position"]
            
            elif msg.topic == "lora/position":
                if "position" in data:
                    with self.lock:
                        pos = data["position"]
                        self.tag_position = pos
                        self.position_history.append((pos["x"], pos["y"]))
                        if len(self.position_history) > self.max_trail:
                            self.position_history.pop(0)
                            
        except Exception as e:
            logger.error(f"Error: {e}")
    
    def run(self):
        """Start visualization"""
        if not MATPLOTLIB_AVAILABLE:
            logger.error("matplotlib required. Install: pip3 install matplotlib")
            return
        
        self.connect_mqtt()
        
        fig, ax = plt.subplots(figsize=(10, 10))
        ax.set_xlim(-1, self.room_width + 1)
        ax.set_ylim(-1, self.room_height + 1)
        ax.set_aspect('equal')
        ax.grid(True, alpha=0.3)
        ax.set_xlabel('X (meters)')
        ax.set_ylabel('Y (meters)')
        ax.set_title('LoRa Tag Tracking - Real-time Position')
        
        # Room boundary
        room = plt.Rectangle((0, 0), self.room_width, self.room_height,
                             fill=False, edgecolor='black', linewidth=2)
        ax.add_patch(room)
        
        # Plot elements
        receiver_scatter = ax.scatter([], [], c='blue', s=200, marker='^', 
                                      label='Receivers', zorder=5)
        tag_scatter = ax.scatter([], [], c='red', s=300, marker='o',
                                 label='Tag', zorder=10)
        trail_line, = ax.plot([], [], 'r-', alpha=0.5, linewidth=1, label='Trail')
        
        receiver_labels = []
        position_text = ax.text(0.02, 0.98, '', transform=ax.transAxes,
                               verticalalignment='top', fontsize=10,
                               bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
        
        ax.legend(loc='upper right')
        
        def update(frame):
            with self.lock:
                if self.receivers:
                    rx = [r["x"] for r in self.receivers.values()]
                    ry = [r["y"] for r in self.receivers.values()]
                    receiver_scatter.set_offsets(list(zip(rx, ry)))
                    
                    for label in receiver_labels:
                        label.remove()
                    receiver_labels.clear()
                    
                    for rid, pos in self.receivers.items():
                        label = ax.annotate(rid, (pos["x"], pos["y"]),
                                          xytext=(5, 5), textcoords='offset points',
                                          fontsize=9, fontweight='bold')
                        receiver_labels.append(label)
                
                tag_scatter.set_offsets([[self.tag_position["x"], self.tag_position["y"]]])
                
                if self.position_history:
                    trail_x = [p[0] for p in self.position_history]
                    trail_y = [p[1] for p in self.position_history]
                    trail_line.set_data(trail_x, trail_y)
                
                position_text.set_text(
                    f'Position: ({self.tag_position["x"]:.2f}, {self.tag_position["y"]:.2f})\n'
                    f'Receivers: {len(self.receivers)}'
                )
            
            return receiver_scatter, tag_scatter, trail_line, position_text
        
        ani = animation.FuncAnimation(fig, update, interval=100, blit=False)
        plt.tight_layout()
        plt.show()
        
        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()


def main():
    parser = argparse.ArgumentParser(description='Position Visualizer - MQTT')
    parser.add_argument('--mqtt-host', default='localhost', help='MQTT broker IP')
    parser.add_argument('--mqtt-port', type=int, default=1883, help='MQTT port')
    parser.add_argument('--width', type=float, default=10, help='Room width (m)')
    parser.add_argument('--height', type=float, default=10, help='Room height (m)')
    
    args = parser.parse_args()
    
    viz = PositionVisualizer(
        mqtt_host=args.mqtt_host,
        mqtt_port=args.mqtt_port,
        room_width=args.width,
        room_height=args.height
    )
    viz.run()


if __name__ == "__main__":
    main()
