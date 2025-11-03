"""
Enhanced Byzantine Generals Problem Implementation
Includes network simulation, visualization, and multiple algorithm variations
"""

import random
import time
import threading
import queue
from typing import Dict, List, Optional, Set, Tuple, Any
from collections import defaultdict
from dataclasses import dataclass, field
from enum import Enum
import json
from abc import ABC, abstractmethod

# Try to import visualization libraries (optional)
try:
    import matplotlib.pyplot as plt
    import networkx as nx
    VISUALIZATION_AVAILABLE = True
except ImportError:
    VISUALIZATION_AVAILABLE = False


class Action(Enum):
    """Possible actions for generals"""
    ATTACK = "ATTACK"
    RETREAT = "RETREAT"
    UNKNOWN = "UNKNOWN"
    
    @classmethod
    def random(cls):
        return random.choice([cls.ATTACK, cls.RETREAT])


@dataclass
class NetworkMessage:
    """Message that travels through the network"""
    sender_id: int
    receiver_id: int
    content: Any
    timestamp: float = field(default_factory=time.time)
    path: List[int] = field(default_factory=list)
    round_num: int = 0
    signature: Optional[str] = None


class NetworkSimulator:
    """Simulates network communication with delays and potential failures"""
    
    def __init__(self, latency_ms: float = 10, loss_rate: float = 0.0):
        self.latency_ms = latency_ms
        self.loss_rate = loss_rate
        self.message_log: List[NetworkMessage] = []
        self.message_queues: Dict[int, queue.Queue] = {}
        
    def register_node(self, node_id: int):
        """Register a node in the network"""
        self.message_queues[node_id] = queue.Queue()
    
    def send_message(self, message: NetworkMessage):
        """Send a message through the network"""
        # Simulate message loss
        if random.random() < self.loss_rate:
            return  # Message lost
        
        # Log the message
        self.message_log.append(message)
        
        # Simulate network delay
        def deliver():
            time.sleep(self.latency_ms / 1000)
            if message.receiver_id in self.message_queues:
                self.message_queues[message.receiver_id].put(message)
        
        thread = threading.Thread(target=deliver)
        thread.daemon = True
        thread.start()
    
    def receive_messages(self, node_id: int) -> List[NetworkMessage]:
        """Receive all pending messages for a node"""
        messages = []
        if node_id in self.message_queues:
            while not self.message_queues[node_id].empty():
                try:
                    messages.append(self.message_queues[node_id].get_nowait())
                except queue.Empty:
                    break
        return messages


class ByzantineNode(ABC):
    """Abstract base class for Byzantine nodes"""
    
    def __init__(self, node_id: int, is_faulty: bool = False):
        self.node_id = node_id
        self.is_faulty = is_faulty
        self.decision: Optional[Action] = None
        self.received_values: Dict[int, Dict[str, Action]] = defaultdict(dict)
        self.network: Optional[NetworkSimulator] = None
        
    @abstractmethod
    def process_round(self, round_num: int):
        """Process a single round of the algorithm"""
        pass
    
    @abstractmethod
    def make_decision(self):
        """Make final decision based on received values"""
        pass
    
    def send_value(self, receiver_id: int, value: Action, round_num: int, path: List[int]):
        """Send a value to another node"""
        if self.is_faulty and round_num > 0:
            # Faulty nodes might send different values
            value = Action.random()
        
        message = NetworkMessage(
            sender_id=self.node_id,
            receiver_id=receiver_id,
            content=value,
            round_num=round_num,
            path=path + [self.node_id]
        )
        
        if self.network:
            self.network.send_message(message)
    
    def receive_values(self) -> List[NetworkMessage]:
        """Receive values from the network"""
        if self.network:
            return self.network.receive_messages(self.node_id)
        return []


class OralMessagesNode(ByzantineNode):
    """Node implementing the Oral Messages (OM) algorithm"""
    
    def __init__(self, node_id: int, is_faulty: bool = False, total_nodes: int = 0, max_faulty: int = 0):
        super().__init__(node_id, is_faulty)
        self.total_nodes = total_nodes
        self.max_faulty = max_faulty
        self.is_commander = False
        self.commander_value: Optional[Action] = None
        
    def process_round(self, round_num: int):
        """Process a round of the OM algorithm"""
        if round_num == 0 and self.is_commander:
            # Commander sends initial value
            for i in range(self.total_nodes):
                if i != self.node_id:
                    self.send_value(i, self.commander_value, round_num, [])
        else:
            # Process received messages and relay
            messages = self.receive_values()
            
            for msg in messages:
                # Store the received value
                path_key = "->".join(map(str, msg.path))
                self.received_values[msg.round_num][path_key] = msg.content
                
                # Relay to others if not at max depth
                if msg.round_num < self.max_faulty:
                    path_set = set(msg.path)
                    for i in range(self.total_nodes):
                        if i != self.node_id and i not in path_set:
                            self.send_value(i, msg.content, msg.round_num + 1, msg.path)
    
    def make_decision(self):
        """Apply majority voting to make decision"""
        if self.is_commander:
            self.decision = self.commander_value
            return
        
        # Collect all received values
        all_values = []
        for round_values in self.received_values.values():
            for value in round_values.values():
                all_values.append(value)
        
        if not all_values:
            self.decision = Action.RETREAT
            return
        
        # Majority vote
        attack_count = sum(1 for v in all_values if v == Action.ATTACK)
        self.decision = Action.ATTACK if attack_count > len(all_values) / 2 else Action.RETREAT


class SignedMessagesNode(ByzantineNode):
    """Node implementing the Signed Messages (SM) algorithm"""
    
    def __init__(self, node_id: int, is_faulty: bool = False, total_nodes: int = 0):
        super().__init__(node_id, is_faulty)
        self.total_nodes = total_nodes
        self.signed_messages: List[Tuple[Action, List[int]]] = []
        self.is_commander = False
        self.commander_value: Optional[Action] = None
    
    def sign_message(self, value: Action, signatures: List[int]) -> str:
        """Create a signed message (simulated)"""
        new_signatures = signatures + [self.node_id]
        return f"{value.value}:{':'.join(map(str, new_signatures))}"
    
    def verify_signature(self, signed_msg: str) -> Tuple[Action, List[int]]:
        """Verify and extract signed message content"""
        parts = signed_msg.split(':')
        value = Action[parts[0]]
        signatures = [int(s) for s in parts[1:] if s]
        return value, signatures
    
    def process_round(self, round_num: int):
        """Process a round of the SM algorithm"""
        if round_num == 0 and self.is_commander:
            # Commander sends signed initial value
            signed_msg = self.sign_message(self.commander_value, [])
            for i in range(self.total_nodes):
                if i != self.node_id:
                    message = NetworkMessage(
                        sender_id=self.node_id,
                        receiver_id=i,
                        content=signed_msg,
                        round_num=round_num,
                        signature=signed_msg
                    )
                    if self.network:
                        self.network.send_message(message)
        else:
            # Process received signed messages
            messages = self.receive_values()
            
            for msg in messages:
                if msg.signature:
                    value, signatures = self.verify_signature(msg.signature)
                    
                    # Store if new
                    is_new = True
                    for stored_val, stored_sigs in self.signed_messages:
                        if set(signatures) == set(stored_sigs):
                            is_new = False
                            break
                    
                    if is_new:
                        self.signed_messages.append((value, signatures))
                        
                        # Relay to nodes not in signature chain
                        if len(signatures) <= self.total_nodes:
                            new_signed = self.sign_message(value, signatures)
                            for i in range(self.total_nodes):
                                if i != self.node_id and i not in signatures:
                                    relay_msg = NetworkMessage(
                                        sender_id=self.node_id,
                                        receiver_id=i,
                                        content=new_signed,
                                        round_num=round_num + 1,
                                        signature=new_signed
                                    )
                                    if self.network:
                                        self.network.send_message(relay_msg)
    
    def make_decision(self):
        """Make decision based on signed messages"""
        if self.is_commander:
            self.decision = self.commander_value
            return
        
        # Extract all values from signed messages
        values = [val for val, _ in self.signed_messages]
        
        if not values:
            self.decision = Action.RETREAT
            return
        
        # Use majority or default
        attack_count = sum(1 for v in values if v == Action.ATTACK)
        self.decision = Action.ATTACK if attack_count > len(values) / 2 else Action.RETREAT


class ByzantineSimulator:
    """Main simulator for Byzantine Generals algorithms"""
    
    def __init__(self, algorithm: str = "OM", visualization: bool = False):
        self.algorithm = algorithm
        self.nodes: Dict[int, ByzantineNode] = {}
        self.network = NetworkSimulator()
        self.visualization = visualization and VISUALIZATION_AVAILABLE
        self.history: List[Dict] = []
        
    def setup(self, n: int, f: int, commander_id: int = 0, faulty_nodes: Optional[List[int]] = None):
        """Setup the Byzantine system"""
        if self.algorithm == "OM" and n <= 3 * f:
            raise ValueError(f"OM algorithm needs n > 3f. Got n={n}, f={f}")
        elif self.algorithm == "SM" and n <= f:
            raise ValueError(f"SM algorithm needs n > f. Got n={n}, f={f}")
        
        # Determine faulty nodes
        if faulty_nodes is None:
            available = [i for i in range(n) if i != commander_id]
            faulty_nodes = random.sample(available, min(f, len(available)))
        
        # Create nodes
        for i in range(n):
            is_faulty = i in faulty_nodes
            
            if self.algorithm == "OM":
                node = OralMessagesNode(i, is_faulty, n, f)
            else:  # SM
                node = SignedMessagesNode(i, is_faulty, n)
            
            node.network = self.network
            self.network.register_node(i)
            
            if i == commander_id:
                node.is_commander = True
            
            self.nodes[i] = node
        
        print(f"System setup: {n} nodes, up to {f} faulty")
        print(f"Faulty nodes: {sorted(faulty_nodes)}")
        print(f"Commander: Node {commander_id}")
        
    def run(self, commander_value: Action, rounds: Optional[int] = None):
        """Run the Byzantine algorithm"""
        if rounds is None:
            rounds = len([n for n in self.nodes.values() if n.is_faulty]) + 1
        
        # Set commander value
        commander = next(n for n in self.nodes.values() if n.is_commander)
        commander.commander_value = commander_value
        
        print(f"\nRunning {self.algorithm} algorithm for {rounds} rounds")
        print(f"Commander orders: {commander_value.value}")
        
        # Run rounds
        for round_num in range(rounds):
            print(f"\nRound {round_num}:")
            
            # All nodes process the round
            for node in self.nodes.values():
                node.process_round(round_num)
            
            # Wait for messages to propagate
            time.sleep(0.1)
            
            # Log state
            self.log_round_state(round_num)
        
        # Make decisions
        print("\nMaking final decisions...")
        for node in self.nodes.values():
            node.make_decision()
        
        # Check consensus
        self.check_consensus()
        
        # Visualize if enabled
        if self.visualization:
            self.visualize_system()
    
    def log_round_state(self, round_num: int):
        """Log the state after a round"""
        state = {
            'round': round_num,
            'nodes': {}
        }
        
        for node_id, node in self.nodes.items():
            state['nodes'][node_id] = {
                'is_faulty': node.is_faulty,
                'is_commander': node.is_commander,
                'received_values': dict(node.received_values)
            }
        
        self.history.append(state)
        
        # Print summary
        msg_count = len(self.network.message_log)
        print(f"  Total messages sent: {msg_count}")
    
    def check_consensus(self):
        """Check if consensus was achieved"""
        print("\n" + "=" * 50)
        print("RESULTS:")
        
        # Print each node's decision
        for node_id in sorted(self.nodes.keys()):
            node = self.nodes[node_id]
            status = []
            if node.is_commander:
                status.append("COMMANDER")
            if node.is_faulty:
                status.append("FAULTY")
            status_str = f" ({', '.join(status)})" if status else ""
            print(f"Node {node_id}{status_str}: {node.decision.value if node.decision else 'NONE'}")
        
        # Check consensus among loyal nodes
        loyal_nodes = [n for n in self.nodes.values() if not n.is_faulty and not n.is_commander]
        if loyal_nodes:
            decisions = [n.decision for n in loyal_nodes]
            unique_decisions = set(decisions)
            
            print("\n" + "-" * 50)
            if len(unique_decisions) == 1:
                print("✓ CONSENSUS ACHIEVED among loyal nodes!")
                print(f"  Decision: {decisions[0].value}")
                
                # Check IC2 if commander is loyal
                commander = next(n for n in self.nodes.values() if n.is_commander)
                if not commander.is_faulty:
                    if all(n.decision == commander.decision for n in loyal_nodes):
                        print("✓ IC2 SATISFIED: Loyal nodes follow loyal commander")
                    else:
                        print("✗ IC2 VIOLATED: Loyal nodes didn't follow loyal commander")
            else:
                print("✗ CONSENSUS FAILED among loyal nodes!")
                print(f"  Decisions: {[d.value for d in unique_decisions]}")
    
    def visualize_system(self):
        """Visualize the Byzantine system"""
        if not VISUALIZATION_AVAILABLE:
            print("Visualization not available (install matplotlib and networkx)")
            return
        
        plt.figure(figsize=(12, 8))
        
        # Create graph
        G = nx.DiGraph()
        for node_id in self.nodes.keys():
            G.add_node(node_id)
        
        # Add edges from message log
        for msg in self.network.message_log[:50]:  # Limit to first 50 messages
            G.add_edge(msg.sender_id, msg.receiver_id)
        
        # Node colors
        node_colors = []
        for node_id in G.nodes():
            node = self.nodes[node_id]
            if node.is_commander:
                node_colors.append('gold')
            elif node.is_faulty:
                node_colors.append('red')
            else:
                node_colors.append('lightblue')
        
        # Layout
        pos = nx.spring_layout(G, k=2, iterations=50)
        
        # Draw
        nx.draw_networkx_nodes(G, pos, node_color=node_colors, node_size=1000)
        nx.draw_networkx_labels(G, pos)
        nx.draw_networkx_edges(G, pos, edge_color='gray', arrows=True, alpha=0.5)
        
        # Add decision labels
        decision_labels = {}
        for node_id, node in self.nodes.items():
            if node.decision:
                decision_labels[node_id] = node.decision.value[0]  # First letter
        
        pos_above = {k: (v[0], v[1] + 0.1) for k, v in pos.items()}
        nx.draw_networkx_labels(G, pos_above, decision_labels, font_size=8)
        
        plt.title(f"Byzantine Generals System - {self.algorithm} Algorithm")
        plt.axis('off')
        
        # Legend
        from matplotlib.patches import Patch
        legend_elements = [
            Patch(facecolor='gold', label='Commander'),
            Patch(facecolor='red', label='Faulty'),
            Patch(facecolor='lightblue', label='Loyal')
        ]
        plt.legend(handles=legend_elements, loc='upper right')
        
        plt.tight_layout()
        plt.show()


def demo():
    """Run demonstration of different Byzantine algorithms"""
    
    print("BYZANTINE GENERALS PROBLEM DEMONSTRATION")
    print("=" * 60)
    
    # Demo 1: Oral Messages with minimum nodes
    print("\n1. ORAL MESSAGES (OM) - Minimum Case")
    print("-" * 40)
    sim1 = ByzantineSimulator("OM", visualization=False)
    sim1.setup(n=4, f=1, commander_id=0)
    sim1.run(Action.ATTACK)
    
    # Demo 2: Signed Messages
    print("\n\n2. SIGNED MESSAGES (SM)")
    print("-" * 40)
    sim2 = ByzantineSimulator("SM", visualization=False)
    sim2.setup(n=3, f=1, commander_id=0)
    sim2.run(Action.RETREAT)
    
    # Demo 3: Larger system
    print("\n\n3. LARGER SYSTEM - OM Algorithm")
    print("-" * 40)
    sim3 = ByzantineSimulator("OM", visualization=False)
    sim3.setup(n=7, f=2, commander_id=3)
    sim3.run(Action.ATTACK)
    
    print("\n" + "=" * 60)
    print("Demonstration complete!")


if __name__ == "__main__":
    import sys
    
    if "--demo" in sys.argv:
        demo()
    else:
        # Interactive mode
        print("\nBYZANTINE GENERALS SIMULATOR")
        print("=" * 40)
        
        algorithm = input("Choose algorithm (OM/SM): ").upper()
        if algorithm not in ["OM", "SM"]:
            algorithm = "OM"
        
        n = int(input("Number of nodes: "))
        f = int(input("Max faulty nodes: "))
        
        viz = input("Enable visualization? (y/n): ").lower() == 'y'
        
        sim = ByzantineSimulator(algorithm, visualization=viz)
        sim.setup(n, f)
        
        order = input("Commander order (ATTACK/RETREAT): ").upper()
        value = Action.ATTACK if order == "ATTACK" else Action.RETREAT
        
        sim.run(value)