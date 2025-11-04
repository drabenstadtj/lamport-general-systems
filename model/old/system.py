"""
Byzantine Generals Problem - Oral Messages (OM) Algorithm Implementation
A distributed system simulation where nodes act independently with configurable network topology
"""

import random
import copy
from typing import Dict, List, Optional, Set, Tuple
from collections import defaultdict
import json
from enum import Enum
import networkx as nx
import matplotlib.pyplot as plt

class Action(Enum):
    """Possible actions for generals"""
    ATTACK = "ATTACK"
    RETREAT = "RETREAT"
    
    @classmethod
    def random(cls):
        return random.choice([cls.ATTACK, cls.RETREAT])


class NetworkTopology:
    """Manages network topology and connectivity between nodes"""
    
    def __init__(self, n: int, topology_type: str = "complete"):
        """
        Initialize network topology
        topology_type: 'complete', 'ring', 'star', 'mesh', 'random', or 'custom'
        """
        self.n = n
        self.topology_type = topology_type
        self.graph = nx.Graph()
        self.graph.add_nodes_from(range(n))
        self._build_topology()
    
    def _build_topology(self):
        """Build the specified network topology"""
        if self.topology_type == "complete":
            # Fully connected - every node connects to every other node
            for i in range(self.n):
                for j in range(i + 1, self.n):
                    self.graph.add_edge(i, j)
        
        elif self.topology_type == "ring":
            # Ring topology - each node connects to its two neighbors
            for i in range(self.n):
                self.graph.add_edge(i, (i + 1) % self.n)
        
        elif self.topology_type == "star":
            # Star topology - all nodes connect to node 0 (hub)
            for i in range(1, self.n):
                self.graph.add_edge(0, i)
        
        elif self.topology_type == "mesh":
            # Partial mesh - each node connects to sqrt(n) random nodes
            import math
            connections = min(int(math.sqrt(self.n)) + 1, self.n - 1)
            for i in range(self.n):
                # Connect to 'connections' random nodes
                available = [j for j in range(self.n) if j != i and not self.graph.has_edge(i, j)]
                if available:
                    targets = random.sample(available, min(connections, len(available)))
                    for target in targets:
                        self.graph.add_edge(i, target)
        
        elif self.topology_type == "random":
            # Random topology with probability p=0.3 for each edge
            for i in range(self.n):
                for j in range(i + 1, self.n):
                    if random.random() < 0.3:
                        self.graph.add_edge(i, j)
        
        elif self.topology_type == "tree":
            # Binary tree topology
            for i in range(self.n):
                left_child = 2 * i + 1
                right_child = 2 * i + 2
                if left_child < self.n:
                    self.graph.add_edge(i, left_child)
                if right_child < self.n:
                    self.graph.add_edge(i, right_child)
        
        # Ensure graph is connected (add minimum edges if needed)
        if not nx.is_connected(self.graph):
            components = list(nx.connected_components(self.graph))
            # Connect components
            for i in range(len(components) - 1):
                node1 = list(components[i])[0]
                node2 = list(components[i + 1])[0]
                self.graph.add_edge(node1, node2)
    
    def get_neighbors(self, node_id: int) -> List[int]:
        """Get list of direct neighbors for a node"""
        return list(self.graph.neighbors(node_id))
    
    def can_communicate(self, sender: int, receiver: int) -> bool:
        """Check if two nodes can directly communicate"""
        return self.graph.has_edge(sender, receiver)
    
    def get_shortest_path(self, source: int, target: int) -> List[int]:
        """Get shortest path between two nodes"""
        try:
            return nx.shortest_path(self.graph, source, target)
        except nx.NetworkXNoPath:
            return []
    
    def visualize(self, node_colors=None, title="Network Topology"):
        """Visualize the network topology"""
        plt.figure(figsize=(10, 8))
        
        # Choose layout based on topology type
        if self.topology_type == "ring":
            pos = nx.circular_layout(self.graph)
        elif self.topology_type == "star":
            pos = nx.spring_layout(self.graph, k=2)
        elif self.topology_type == "tree":
            pos = nx.spring_layout(self.graph, k=3, iterations=50)
        else:
            pos = nx.spring_layout(self.graph, k=2, iterations=50)
        
        # Default node colors if not provided
        if node_colors is None:
            node_colors = ['lightblue'] * self.n
        
        # Draw the graph
        nx.draw_networkx_nodes(self.graph, pos, node_color=node_colors, 
                             node_size=1000, alpha=0.9)
        nx.draw_networkx_labels(self.graph, pos, font_size=12, font_weight='bold')
        nx.draw_networkx_edges(self.graph, pos, width=2, alpha=0.6, edge_color='gray')
        
        plt.title(f"{title} - {self.topology_type.capitalize()} Topology")
        plt.axis('off')
        plt.tight_layout()
        plt.show()
    
    def get_stats(self) -> Dict:
        """Get statistics about the network topology"""
        return {
            'nodes': self.n,
            'edges': self.graph.number_of_edges(),
            'avg_degree': sum(dict(self.graph.degree()).values()) / self.n,
            'diameter': nx.diameter(self.graph) if nx.is_connected(self.graph) else float('inf'),
            'is_connected': nx.is_connected(self.graph),
            'density': nx.density(self.graph)
        }

class MessageType(Enum):
    """Types of messages in the system"""
    DIRECT = "DIRECT"
    RELAY = "RELAY"

class Message:
    """Represents a message in the Byzantine system"""
    def __init__(self, sender: int, value: Action, path: List[int], msg_type: MessageType):
        self.sender = sender
        self.value = value
        self.path = path.copy()  # Path the message has traveled
        self.type = msg_type
    
    def __repr__(self):
        return f"Message(from={self.sender}, value={self.value.value}, path={self.path})"

class General:
    """Represents a single general (node) in the Byzantine system"""
    
    def __init__(self, node_id: int, is_traitor: bool = False, is_commander: bool = False):
        self.node_id = node_id
        self.is_traitor = is_traitor
        self.is_commander = is_commander
        self.received_messages: Dict[str, List[Message]] = defaultdict(list)
        self.decision: Optional[Action] = None
        self.round_messages: List[Tuple[int, Message]] = []  # Messages to send this round
        self.message_buffer: List[Tuple[int, Message, int]] = []  # (target, message, hop_count)
        
    def create_message(self, value: Action, path: List[int], msg_type: MessageType) -> Message:
        """Create a message from this general"""
        new_path = path + [self.node_id]
        if self.is_traitor and not self.is_commander:
            # Traitor might send different values to different generals
            value = Action.random()
        return Message(self.node_id, value, new_path, msg_type)
    
    def receive_message(self, message: Message, round_num: int):
        """Receive and store a message"""
        # Create a unique key for the message based on its path
        path_key = "->".join(map(str, message.path))
        self.received_messages[path_key].append(message)
        
    def prepare_relay_messages(self, round_num: int, max_rounds: int, topology: NetworkTopology):
        """Prepare messages to relay in the next round (topology-aware)"""
        if round_num >= max_rounds:
            return []
        
        messages_to_relay = []
        neighbors = topology.get_neighbors(self.node_id)
        
        # Relay messages received in this round
        for path_key, messages in self.received_messages.items():
            for msg in messages:
                # Don't relay to generals already in the path
                path_set = set(msg.path)
                
                # Only relay to direct neighbors
                for neighbor in neighbors:
                    if neighbor not in path_set:
                        relay_msg = self.create_message(
                            msg.value, 
                            msg.path,
                            MessageType.RELAY
                        )
                        messages_to_relay.append((neighbor, relay_msg))
        
        return messages_to_relay
    
    def route_message(self, target: int, message: Message, topology: NetworkTopology) -> List[Tuple[int, Message]]:
        """Route a message to target through the network topology"""
        if topology.can_communicate(self.node_id, target):
            # Direct communication possible
            return [(target, message)]
        
        # Find shortest path and send to next hop
        path = topology.get_shortest_path(self.node_id, target)
        if len(path) > 1:
            next_hop = path[1]  # Next node in the path
            return [(next_hop, message)]
        
        return []  # No path available
    
    def make_decision(self, m: int):
        """Apply the OM(m) decision rule"""
        if self.is_commander:
            # Commander keeps its original value
            return
        
        # Collect all values received
        values = []
        
        # Process messages by path length (shorter paths = higher rounds)
        for path_key, messages in self.received_messages.items():
            for msg in messages:
                values.append(msg.value)
        
        if not values:
            self.decision = Action.RETREAT  # Default if no messages received
            return
        
        # Take majority vote
        attack_count = sum(1 for v in values if v == Action.ATTACK)
        retreat_count = len(values) - attack_count
        
        self.decision = Action.ATTACK if attack_count > retreat_count else Action.RETREAT
    
    def __repr__(self):
        traitor_str = " (TRAITOR)" if self.is_traitor else ""
        commander_str = " (COMMANDER)" if self.is_commander else ""
        return f"General {self.node_id}{commander_str}{traitor_str}: {self.decision}"

class ByzantineSystem:
    """Simulates the Byzantine Generals distributed system with network topology"""
    
    def __init__(self, n: int, m: int, commander_id: int = 0, topology_type: str = "complete"):
        """
        Initialize the Byzantine system
        n: total number of generals
        m: number of traitors (byzantine failures to tolerate)
        commander_id: ID of the commander general
        topology_type: 'complete', 'ring', 'star', 'mesh', 'random', 'tree'
        """
        if n <= 3 * m:
            raise ValueError(f"Need n > 3m for OM algorithm. Got n={n}, m={m}, need n > {3*m}")
        
        self.n = n
        self.m = m
        self.commander_id = commander_id
        self.topology = NetworkTopology(n, topology_type)
        self.generals: Dict[int, General] = {}
        self.message_queue: List[Tuple[int, int, Message]] = []  # (round, target, message)
        
        # Initialize generals
        self._initialize_generals()
        
    def _initialize_generals(self):
        """Create generals with random traitor assignment"""
        # Randomly select traitors (excluding commander for this example)
        available_ids = [i for i in range(self.n) if i != self.commander_id]
        traitor_ids = set(random.sample(available_ids, min(self.m, len(available_ids))))
        
        for i in range(self.n):
            is_traitor = i in traitor_ids
            is_commander = (i == self.commander_id)
            self.generals[i] = General(i, is_traitor, is_commander)
        
        print(f"System initialized with {self.n} generals, {self.m} max traitors")
        print(f"Network topology: {self.topology.topology_type}")
        stats = self.topology.get_stats()
        print(f"Network stats: {stats['edges']} edges, avg degree: {stats['avg_degree']:.2f}, diameter: {stats['diameter']}")
        print(f"Actual traitors: {sorted(traitor_ids)}")
    
    def run_om_algorithm(self, commander_value: Action, visualize_topology: bool = False) -> Dict[int, Action]:
        """
        Run the Oral Messages OM(m) algorithm with network topology awareness
        Returns the final decisions of all generals
        """
        print(f"\nStarting OM({self.m}) algorithm with {self.topology.topology_type} topology")
        print(f"Commander {self.commander_id} orders: {commander_value.value}")
        print("-" * 50)
        
        # Optionally visualize the topology
        if visualize_topology:
            node_colors = []
            for i in range(self.n):
                if i == self.commander_id:
                    node_colors.append('gold')
                elif self.generals[i].is_traitor:
                    node_colors.append('red')
                else:
                    node_colors.append('lightblue')
            self.topology.visualize(node_colors, "Byzantine Generals Network")
        
        # Set commander's decision
        commander = self.generals[self.commander_id]
        commander.decision = commander_value
        
        # Round 0: Commander sends to all neighbors (or all if complete topology)
        print("\nRound 0: Commander sends initial orders")
        commander_neighbors = self.topology.get_neighbors(self.commander_id)
        
        if self.topology.topology_type == "complete":
            # In complete topology, send to all
            targets = [i for i in range(self.n) if i != self.commander_id]
        else:
            # In other topologies, send only to neighbors
            targets = commander_neighbors
        
        for target in targets:
            msg = commander.create_message(
                commander_value,
                [],
                MessageType.DIRECT
            )
            self.generals[target].receive_message(msg, 0)
            print(f"  Commander -> General {target}: {msg.value.value}")
        
        # For non-complete topologies, propagate commander's message
        if self.topology.topology_type != "complete":
            print("\n  Propagating commander's message through network...")
            visited = set([self.commander_id] + targets)
            to_visit = targets.copy()
            
            while to_visit:
                current = to_visit.pop(0)
                neighbors = self.topology.get_neighbors(current)
                
                for neighbor in neighbors:
                    if neighbor not in visited and neighbor != self.commander_id:
                        # Forward the commander's message
                        msg = self.generals[current].create_message(
                            commander_value,
                            [self.commander_id],
                            MessageType.RELAY
                        )
                        self.generals[neighbor].receive_message(msg, 0)
                        visited.add(neighbor)
                        to_visit.append(neighbor)
                        print(f"    General {current} -> General {neighbor}: {msg.value.value}")
        
        # Rounds 1 to m: Lieutenants relay messages
        for round_num in range(1, self.m + 1):
            print(f"\nRound {round_num}: Relaying messages")
            round_messages = []
            
            for general_id, general in self.generals.items():
                if general_id == self.commander_id:
                    continue
                    
                # Prepare messages to relay (topology-aware)
                relay_messages = general.prepare_relay_messages(
                    round_num - 1, 
                    self.m,
                    self.topology
                )
                round_messages.extend(relay_messages)
            
            # Deliver all messages for this round
            messages_sent = 0
            for target, message in round_messages:
                if target != self.commander_id:  # Don't send back to commander
                    self.generals[target].receive_message(message, round_num)
                    messages_sent += 1
            
            print(f"  {messages_sent} messages relayed")
            
            # Show some routing information for non-complete topologies
            if self.topology.topology_type != "complete" and round_num == 1 and messages_sent > 0:
                print(f"  (Messages routed through {self.topology.topology_type} topology connections)")
        
        # Make decisions
        print("\nMaking final decisions...")
        for general_id, general in self.generals.items():
            general.make_decision(self.m)
        
        return {g.node_id: g.decision for g in self.generals.values()}
    
    def verify_consensus(self) -> bool:
        """Check if loyal generals reached consensus"""
        loyal_decisions = [
            g.decision for g in self.generals.values() 
            if not g.is_traitor and not g.is_commander
        ]
        
        if not loyal_decisions:
            return True
        
        # All loyal generals should have the same decision
        return len(set(loyal_decisions)) == 1
    
    def print_results(self):
        """Print the final state of all generals"""
        print("\n" + "=" * 50)
        print("FINAL RESULTS:")
        print("=" * 50)
        
        for general in sorted(self.generals.values(), key=lambda g: g.node_id):
            print(general)
        
        # Check consensus
        consensus = self.verify_consensus()
        print("\n" + "-" * 50)
        
        if consensus:
            print("✓ CONSENSUS ACHIEVED among loyal generals!")
            loyal_decision = next(
                (g.decision for g in self.generals.values() 
                 if not g.is_traitor and not g.is_commander),
                None
            )
            if loyal_decision:
                print(f"  Loyal generals agreed on: {loyal_decision.value}")
        else:
            print("✗ CONSENSUS FAILED among loyal generals!")
        
        # If commander is loyal, check IC2
        commander = self.generals[self.commander_id]
        if not commander.is_traitor:
            loyal_follow_commander = all(
                g.decision == commander.decision
                for g in self.generals.values()
                if not g.is_traitor and not g.is_commander
            )
            if loyal_follow_commander:
                print(f"✓ IC2 SATISFIED: Loyal generals follow loyal commander's order: {commander.decision.value}")
            else:
                print("✗ IC2 VIOLATED: Some loyal generals didn't follow loyal commander!")


def run_example():
    """Run example scenarios of the Byzantine Generals Problem with different topologies"""
    
    print("BYZANTINE GENERALS PROBLEM - ORAL MESSAGES (OM) ALGORITHM")
    print("WITH NETWORK TOPOLOGY SUPPORT")
    print("=" * 60)
    
    # Example 1: Complete topology (original)
    print("\n\nEXAMPLE 1: Complete Topology (n=4, m=1)")
    print("Fully connected network - original Byzantine Generals")
    system1 = ByzantineSystem(n=4, m=1, topology_type="complete")
    decisions1 = system1.run_om_algorithm(Action.ATTACK)
    system1.print_results()
    
    # Example 2: Ring topology
    print("\n\n" + "=" * 60)
    print("EXAMPLE 2: Ring Topology (n=7, m=2)")
    print("Each general only connects to two neighbors")
    system2 = ByzantineSystem(n=7, m=2, topology_type="ring")
    decisions2 = system2.run_om_algorithm(Action.RETREAT)
    system2.print_results()
    
    # Example 3: Star topology
    print("\n\n" + "=" * 60)
    print("EXAMPLE 3: Star Topology (n=7, m=2)")
    print("All generals connect through a central hub")
    system3 = ByzantineSystem(n=7, m=2, commander_id=0, topology_type="star")
    decisions3 = system3.run_om_algorithm(Action.ATTACK)
    system3.print_results()
    
    # Example 4: Mesh topology
    print("\n\n" + "=" * 60)
    print("EXAMPLE 4: Partial Mesh Topology (n=10, m=3)")
    print("Each general connects to sqrt(n) other generals")
    system4 = ByzantineSystem(n=10, m=3, topology_type="mesh")
    decisions4 = system4.run_om_algorithm(Action.ATTACK)
    system4.print_results()


def interactive_mode():
    """Run the system with user-specified parameters and topology"""
    print("\nINTERACTIVE MODE - BYZANTINE GENERALS WITH NETWORK TOPOLOGY")
    print("=" * 60)
    
    while True:
        try:
            n = int(input("\nEnter number of generals (n): "))
            m = int(input("Enter max number of traitors to tolerate (m): "))
            
            if n <= 3 * m:
                print(f"Error: Need n > 3m. For m={m}, need n > {3*m}")
                continue
            
            print("\nAvailable topologies:")
            print("1. complete - Fully connected (original)")
            print("2. ring - Ring topology")
            print("3. star - Star topology")
            print("4. mesh - Partial mesh")
            print("5. random - Random connections")
            print("6. tree - Binary tree")
            
            topology = input("Choose topology (default: complete): ").lower()
            if topology not in ["complete", "ring", "star", "mesh", "random", "tree"]:
                topology = "complete"
            
            commander_id = int(input(f"Enter commander ID (0 to {n-1}): "))
            if commander_id < 0 or commander_id >= n:
                print(f"Error: Commander ID must be between 0 and {n-1}")
                continue
            
            order = input("Enter commander's order (ATTACK/RETREAT): ").upper()
            if order not in ["ATTACK", "RETREAT"]:
                print("Error: Order must be ATTACK or RETREAT")
                continue
            
            visualize = input("Visualize network topology? (y/n): ").lower() == 'y'
            
            action = Action.ATTACK if order == "ATTACK" else Action.RETREAT
            
            system = ByzantineSystem(n, m, commander_id, topology_type=topology)
            decisions = system.run_om_algorithm(action, visualize_topology=visualize)
            system.print_results()
            
            again = input("\nRun another simulation? (y/n): ").lower()
            if again != 'y':
                break
                
        except ValueError as e:
            print(f"Invalid input: {e}")
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--interactive":
        interactive_mode()
    else:
        run_example()