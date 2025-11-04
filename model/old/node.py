import random
from typing import List, Dict, Set, Tuple, Optional
from collections import deque

# Constants for decision values
ATTACK = "ATTACK"
RETREAT = "RETREAT"
DEFAULT_VALUE = RETREAT

class Network:
    nodes = {}
    
    @classmethod
    def register_node(cls, node):
        cls.nodes[node.node_id] = node
    
    @classmethod
    def deliver_message(cls, target_node_id: int, message: Dict):
        if target_node_id in cls.nodes:
            cls.nodes[target_node_id].receive_message(message)

class Node:
    def __init__(self, node_id: int, neighbors: List[int], is_traitor: bool = False):
        self.node_id = node_id
        self.is_traitor = is_traitor
        self.neighbors = neighbors
        self.received_messages: Dict[int, List[Tuple[str, List[int]]]] = {}  # {round: [(value, path)]}
        self.decision: Optional[str] = None
        self.sent_messages: Dict[int, Dict[int, str]] = {}
    
    def send_message(self, value: str, target_node: int, round_num: int, path: List[int] = None):
        if path is None:
            path = []
        
        # Byzantine behavior for traitors
        if self.is_traitor and round_num > 0:
            # Strategic lying based on target position
            if target_node % 2 == 0:
                value = ATTACK
            else:
                value = RETREAT
        
        new_path = path + [self.node_id]
        
        # Track sent messages
        if round_num not in self.sent_messages:
            self.sent_messages[round_num] = {}
        self.sent_messages[round_num][target_node] = value
        
        message = {
            'value': value,
            'sender': self.node_id,
            'round': round_num,
            'path': new_path
        }
        
        Network.deliver_message(target_node, message)
    
    def receive_message(self, message: Dict):
        round_num = message['round']
        
        if round_num not in self.received_messages:
            self.received_messages[round_num] = []
        
        # Store both value and path for path verification
        self.received_messages[round_num].append((message['value'], message['path']))
    
    def get_majority_from_paths(self, round_num: int) -> str:
        """Get majority value from all disjoint paths in a round"""
        if round_num not in self.received_messages:
            return DEFAULT_VALUE
        
        # Count values from unique paths (avoid counting duplicates)
        unique_messages = set()
        for value, path in self.received_messages[round_num]:
            path_key = tuple(path)  # Use path as unique identifier
            unique_messages.add((value, path_key))
        
        values = [msg[0] for msg in unique_messages]
        
        if not values:
            return DEFAULT_VALUE
        
        attack_count = values.count(ATTACK)
        retreat_count = values.count(RETREAT)
        
        return ATTACK if attack_count > retreat_count else RETREAT

class Commander(Node):
    def __init__(self, node_id: int, neighbors: List[int], initial_value: str):
        super().__init__(node_id, neighbors, is_traitor=False)
        self.initial_value = initial_value
        self.decision = initial_value

class PartialTopologyBFT:
    def __init__(self):
        self.nodes: Dict[int, Node] = {}
        self.commander_id: int = 0
        self.graph: Dict[int, Set[int]] = {}  # adjacency list
    
    def add_node(self, node_id: int, neighbors: List[int], is_traitor: bool = False):
        self.nodes[node_id] = Node(node_id, neighbors, is_traitor)
        Network.register_node(self.nodes[node_id])
        self.graph[node_id] = set(neighbors)
    
    def set_commander(self, node_id: int, neighbors: List[int], initial_value: str):
        self.commander_id = node_id
        self.nodes[node_id] = Commander(node_id, neighbors, initial_value)
        Network.register_node(self.nodes[node_id])
        self.graph[node_id] = set(neighbors)
    
    def find_all_paths(self, source: int, target: int, max_length: int = 10) -> List[List[int]]:
        """Find all simple paths from source to target using BFS"""
        if source not in self.graph or target not in self.graph:
            return []
        
        paths = []
        queue = deque([(source, [source])])
        
        while queue:
            current, path = queue.popleft()
            
            if current == target:
                paths.append(path)
                continue
            
            if len(path) >= max_length:
                continue
            
            for neighbor in self.graph.get(current, []):
                if neighbor not in path:  # Avoid cycles
                    queue.append((neighbor, path + [neighbor]))
        
        return paths
    
    def are_paths_edge_disjoint(self, path1: List[int], path2: List[int]) -> bool:
        """Check if two paths are edge-disjoint"""
        edges1 = set()
        for i in range(len(path1) - 1):
            edges1.add(tuple(sorted([path1[i], path1[i + 1]])))
        
        edges2 = set()
        for i in range(len(path2) - 1):
            edges2.add(tuple(sorted([path2[i], path2[i + 1]])))
        
        return len(edges1.intersection(edges2)) == 0
    
    def find_disjoint_paths(self, source: int, target: int, k: int) -> List[List[int]]:
        """Find k edge-disjoint paths from source to target"""
        if source == target:
            return []
        
        all_paths = self.find_all_paths(source, target)
        
        # Sort by length to prefer shorter paths
        all_paths.sort(key=len)
        
        disjoint_paths = []
        used_edges = set()
        
        for path in all_paths:
            # Extract edges from this path
            path_edges = set()
            for i in range(len(path) - 1):
                edge = tuple(sorted([path[i], path[i + 1]]))
                path_edges.add(edge)
            
            # Check if this path shares edges with already selected paths
            if not path_edges.intersection(used_edges):
                disjoint_paths.append(path)
                used_edges.update(path_edges)
            
            if len(disjoint_paths) >= k:
                break
        
        return disjoint_paths
    
    def is_graph_connected(self, excluded_nodes: Set[int] = None) -> bool:
        """Check if graph is connected when excluding some nodes"""
        if excluded_nodes is None:
            excluded_nodes = set()
        
        if not self.graph:
            return False
        
        # Find first node not excluded
        start_node = None
        for node in self.graph:
            if node not in excluded_nodes:
                start_node = node
                break
        
        if start_node is None:
            return True  # No nodes to connect
        
        # BFS to check connectivity
        visited = set()
        queue = deque([start_node])
        visited.add(start_node)
        
        while queue:
            current = queue.popleft()
            for neighbor in self.graph.get(current, []):
                if neighbor not in excluded_nodes and neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        
        # Check if all non-excluded nodes are visited
        for node in self.graph:
            if node not in excluded_nodes and node not in visited:
                return False
        
        return True
    
    def calculate_node_connectivity(self) -> int:
        """Calculate the node connectivity of the graph (minimum nodes to remove to disconnect)"""
        if not self.graph:
            return 0
        
        nodes_list = list(self.graph.keys())
        if len(nodes_list) <= 1:
            return 0
        
        # Try removing k nodes and see if graph stays connected
        for k in range(1, len(nodes_list)):
            # Try all combinations of k nodes to remove
            from itertools import combinations
            
            found_disconnecting_set = False
            for nodes_to_remove in combinations(nodes_list, k):
                if not self.is_graph_connected(set(nodes_to_remove)):
                    found_disconnecting_set = True
                    break
            
            if found_disconnecting_set:
                return k - 1  # Connectivity is k-1
        
        return len(nodes_list) - 1
    
    def verify_connectivity(self, m: int, use_signed_messages: bool = False) -> bool:
        """Verify if graph has sufficient connectivity for m traitors"""
        if use_signed_messages:
            required_connectivity = m + 1
            message_type = "signed"
        else:
            required_connectivity = 2 * m + 1
            message_type = "oral"
        
        actual_connectivity = self.calculate_node_connectivity()
        has_sufficient_connectivity = actual_connectivity >= required_connectivity
        
        print(f"Connectivity Check for {m} traitors with {message_type} messages:")
        print(f"  Required: {required_connectivity}-connected")
        print(f"  Actual: {actual_connectivity}-connected")
        print(f"  Result: {'PASS' if has_sufficient_connectivity else 'FAIL'}")
        
        if not has_sufficient_connectivity:
            print("  ❌ Consensus impossible with this topology!")
            return False
        
        return True
    
    def send_via_multipath(self, source: int, target: int, value: str, round_num: int, k: int):
        """Send message via k disjoint paths"""
        if source == target:
            return
        
        paths = self.find_disjoint_paths(source, target, k)
        
        if len(paths) < k:
            print(f"  ⚠️  Only found {len(paths)} disjoint paths from {source} to {target} (need {k})")
        
        for path in paths:
            if len(path) < 2:
                continue
            
            # Send along the path
            current_node = source
            for next_node in path[1:]:  # Skip the source itself
                if current_node in self.nodes and next_node in self.nodes:
                    self.nodes[current_node].send_message(value, next_node, round_num, path[:path.index(current_node)+1])
                current_node = next_node
    
    def run_oral_consensus(self, m: int, initial_value: str):
        """Run oral messages consensus with partial topology"""
        print("=" * 60)
        print("ORAL MESSAGES CONSENSUS WITH PARTIAL TOPOLOGY")
        print("=" * 60)
        
        # Step 1: Verify connectivity
        if not self.verify_connectivity(m, use_signed_messages=False):
            return None
        
        max_rounds = m + 1
        k_paths = 2 * m + 1  # Number of disjoint paths needed
        
        print(f"\nRunning Oral OM({m}) with {k_paths} disjoint paths")
        print(f"Initial value: {initial_value}")
        print(f"Traitors: {[nid for nid, node in self.nodes.items() if node.is_traitor]}")
        
        for round_num in range(max_rounds):
            print(f"\n--- Round {round_num} ---")
            
            if round_num == 0:
                # Commander sends to all nodes via multiple paths
                for target in self.nodes:
                    if target != self.commander_id:
                        self.send_via_multipath(self.commander_id, target, initial_value, round_num, k_paths)
            else:
                # Each node sends to all other nodes via multiple paths
                for source in self.nodes:
                    if source == self.commander_id:
                        continue
                    
                    # Get what this node believes based on previous rounds
                    source_value = self.nodes[source].get_majority_from_paths(round_num - 1)
                    
                    for target in self.nodes:
                        if target != source:
                            self.send_via_multipath(source, target, source_value, round_num, k_paths)
            
            self.print_round_state(round_num)
        
        return self.final_voting()
    
    def run_signed_consensus(self, m: int, initial_value: str):
        """Run signed messages consensus with partial topology"""
        print("=" * 60)
        print("SIGNED MESSAGES CONSENSUS WITH PARTIAL TOPOLOGY")
        print("=" * 60)
        
        # Step 1: Verify connectivity
        if not self.verify_connectivity(m, use_signed_messages=True):
            return None
        
        max_rounds = m + 1
        k_paths = m + 1  # Number of disjoint paths needed
        
        print(f"\nRunning Signed SM({m}) with {k_paths} disjoint paths")
        print(f"Initial value: {initial_value}")
        print(f"Traitors: {[nid for nid, node in self.nodes.items() if node.is_traitor]}")
        
        for round_num in range(max_rounds):
            print(f"\n--- Round {round_num} ---")
            
            if round_num == 0:
                # Commander sends to all nodes
                for target in self.nodes:
                    if target != self.commander_id:
                        self.send_via_multipath(self.commander_id, target, initial_value, round_num, k_paths)
            else:
                # Relay signed messages
                for source in self.nodes:
                    if source == self.commander_id:
                        continue
                    
                    # In signed messages, we relay whatever we received
                    if round_num - 1 in self.nodes[source].received_messages:
                        # Just relay one value (simplified)
                        source_value = self.nodes[source].get_majority_from_paths(round_num - 1)
                        
                        for target in self.nodes:
                            if target != source:
                                self.send_via_multipath(source, target, source_value, round_num, k_paths)
            
            self.print_round_state(round_num)
        
        return self.final_voting()
    
    def print_round_state(self, round_num: int):
        """Print what each node received in this round"""
        print(f"Round {round_num} received messages:")
        for node_id, node in sorted(self.nodes.items()):
            if round_num in node.received_messages:
                messages = node.received_messages[round_num]
                unique_values = set()
                for value, path in messages:
                    unique_values.add(value)
                msg_str = f"{list(unique_values)} from {len(messages)} paths"
            else:
                msg_str = "None"
            
            traitor_str = " [TRAITOR]" if node.is_traitor else ""
            commander_str = " [COMMANDER]" if hasattr(node, 'initial_value') else ""
            print(f"  Node {node_id}{commander_str}{traitor_str}: {msg_str}")
    
    def final_voting(self) -> Dict[int, str]:
        """Final voting phase"""
        print(f"\n--- Final Voting ---")
        decisions = {}
        for node_id, node in sorted(self.nodes.items()):
            # Collect all values from all rounds and paths
            all_values = []
            for round_num in node.received_messages:
                for value, path in node.received_messages[round_num]:
                    all_values.append(value)
            
            if not all_values:
                node.decision = DEFAULT_VALUE
            else:
                attack_count = all_values.count(ATTACK)
                retreat_count = all_values.count(RETREAT)
                node.decision = ATTACK if attack_count > retreat_count else RETREAT
            
            decisions[node_id] = node.decision
            traitor_str = " [TRAITOR]" if node.is_traitor else ""
            commander_str = " [COMMANDER]" if hasattr(node, 'initial_value') else ""
            print(f"Node {node_id}{commander_str}{traitor_str}: {node.decision}")
        
        return decisions
    
    def check_consensus(self, decisions: Dict[int, str]) -> bool:
        """Check consensus conditions"""
        loyal_nodes = {nid: decision for nid, decision in decisions.items() 
                      if not self.nodes[nid].is_traitor and nid != self.commander_id}
        
        if not loyal_nodes:
            return True
        
        first_decision = next(iter(loyal_nodes.values()))
        ic1_satisfied = all(decision == first_decision for decision in loyal_nodes.values())
        
        commander = self.nodes[self.commander_id]
        ic2_satisfied = True
        if not commander.is_traitor:
            ic2_satisfied = all(decision == commander.initial_value for decision in loyal_nodes.values())
        
        print(f"\nConsensus Check:")
        print(f"IC1 (All loyal agree): {ic1_satisfied}")
        print(f"IC2 (Follow loyal commander): {ic2_satisfied}")
        
        return ic1_satisfied and (commander.is_traitor or ic2_satisfied)

# Test cases from the summary
def test_examples():
    print("🧪 TESTING PARTIAL TOPOLOGY BFT")
    
    # Example 1: Line topology that breaks oral messages
    print("\n" + "="*80)
    print("EXAMPLE 1: Line Topology (Should FAIL oral, PASS signed)")
    print("="*80)
    system1 = PartialTopologyBFT()
    # Line: 0-1-2-3-4
    system1.set_commander(0, [1], ATTACK)
    system1.add_node(1, [0, 2])
    system1.add_node(2, [1, 3], is_traitor=True)  # Critical traitor!
    system1.add_node(3, [2, 4])
    system1.add_node(4, [3])
    
    print("Testing ORAL messages:")
    decisions_oral = system1.run_oral_consensus(m=1, initial_value=ATTACK)
    if decisions_oral:
        system1.check_consensus(decisions_oral)
    
    print("\nTesting SIGNED messages:")
    decisions_signed = system1.run_signed_consensus(m=1, initial_value=ATTACK)
    if decisions_signed:
        system1.check_consensus(decisions_signed)
    
    # Example 2: Complete graph that should work
    print("\n" + "="*80)
    print("EXAMPLE 2: Complete Graph (Should PASS both)")
    print("="*80)
    system2 = PartialTopologyBFT()
    # Complete graph with 4 nodes
    system2.set_commander(0, [1, 2, 3], ATTACK)
    system2.add_node(1, [0, 2, 3])
    system2.add_node(2, [0, 1, 3], is_traitor=True)
    system2.add_node(3, [0, 1, 2])
    
    print("Testing ORAL messages:")
    decisions_oral2 = system2.run_oral_consensus(m=1, initial_value=ATTACK)
    if decisions_oral2:
        system2.check_consensus(decisions_oral2)
    
    print("\nTesting SIGNED messages:")
    decisions_signed2 = system2.run_signed_consensus(m=1, initial_value=ATTACK)
    if decisions_signed2:
        system2.check_consensus(decisions_signed2)

if __name__ == "__main__":
    test_examples()