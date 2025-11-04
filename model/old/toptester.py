import random
from typing import List, Dict, Set, Optional
from enum import Enum

class Decision(Enum):
    ATTACK = "ATTACK"
    RETREAT = "RETREAT"
    UNDECIDED = "UNDECIDED"

class Node:
    def __init__(self, node_id: int, is_traitor: bool = False):
        self.node_id = node_id
        self.is_traitor = is_traitor
        self.received_messages: Dict[int, List[Decision]] = {}  # {round: [messages]}
        self.decision: Decision = Decision.UNDECIDED
        self.sent_messages: Dict[int, Dict[int, Decision]] = {}  # {round: {target: value}}
    
    def send_message(self, round_num: int, target_id: int, value: Decision, topology: Dict[int, Set[int]]):
        """Send message directly to target if allowed by topology"""
        if target_id not in topology.get(self.node_id, set()):
            return  # No direct connection
        
        if self.is_traitor:
            # Byzantine behavior: send random conflicting messages
            value = random.choice([Decision.ATTACK, Decision.RETREAT])
        
        # Track sent messages
        if round_num not in self.sent_messages:
            self.sent_messages[round_num] = {}
        self.sent_messages[round_num][target_id] = value
        
        # Deliver message (in real system, this would go through network)
        return value
    
    def receive_message(self, round_num: int, sender_id: int, value: Decision):
        """Receive message from another node"""
        if round_num not in self.received_messages:
            self.received_messages[round_num] = []
        self.received_messages[round_num].append(value)
    
    def vote(self):
        """Make decision based on all received messages"""
        all_values = []
        for round_messages in self.received_messages.values():
            all_values.extend(round_messages)
        
        if not all_values:
            self.decision = Decision.RETREAT  # Default
            return
        
        attack_count = sum(1 for v in all_values if v == Decision.ATTACK)
        retreat_count = sum(1 for v in all_values if v == Decision.RETREAT)
        
        if attack_count > retreat_count:
            self.decision = Decision.ATTACK
        elif retreat_count > attack_count:
            self.decision = Decision.RETREAT
        else:
            self.decision = Decision.RETREAT  # Tie breaker

class Commander(Node):
    def __init__(self, node_id: int, initial_value: Decision):
        super().__init__(node_id, is_traitor=False)
        self.initial_value = initial_value
        self.decision = initial_value
    
    def broadcast_initial(self, round_num: int, topology: Dict[int, Set[int]], nodes: Dict[int, Node]):
        """Commander broadcasts initial value to all connected nodes"""
        for neighbor in topology.get(self.node_id, set()):
            if neighbor in nodes:
                sent_value = self.send_message(round_num, neighbor, self.initial_value, topology)
                if sent_value:
                    nodes[neighbor].receive_message(round_num, self.node_id, sent_value)

class BFTTester:
    def __init__(self):
        self.nodes: Dict[int, Node] = {}
        self.topology: Dict[int, Set[int]] = {}  # node_id: set(neighbors)
        self.commander_id: int = 0
    
    def add_node(self, node_id: int, is_traitor: bool = False):
        self.nodes[node_id] = Node(node_id, is_traitor)
        if node_id not in self.topology:
            self.topology[node_id] = set()
    
    def set_commander(self, node_id: int, initial_value: Decision):
        self.commander_id = node_id
        self.nodes[node_id] = Commander(node_id, initial_value)
        if node_id not in self.topology:
            self.topology[node_id] = set()
    
    def add_connection(self, node1: int, node2: int):
        """Add bidirectional connection"""
        if node1 in self.topology and node2 in self.topology:
            self.topology[node1].add(node2)
            self.topology[node2].add(node1)
    
    def run_round(self, round_num: int):
        """Execute one round of communication"""
        print(f"\n--- Round {round_num} ---")
        
        if round_num == 0:
            # Commander broadcasts initial value
            if self.commander_id in self.nodes:
                commander = self.nodes[self.commander_id]
                if isinstance(commander, Commander):
                    commander.broadcast_initial(round_num, self.topology, self.nodes)
        else:
            # Regular nodes communicate with their neighbors
            for node_id, node in self.nodes.items():
                if node_id == self.commander_id:
                    continue  # Commander only acts in round 0
                
                # Send to all neighbors
                for neighbor_id in self.topology.get(node_id, set()):
                    if neighbor_id == self.commander_id:
                        continue  # Commander doesn't receive after round 0
                    
                    # Decide what value to send (traitors may lie)
                    if round_num == 1:
                        # Base decision on round 0 messages
                        round0_msgs = node.received_messages.get(0, [])
                        value_to_send = round0_msgs[0] if round0_msgs else Decision.RETREAT
                    else:
                        # For later rounds, use majority of previous rounds
                        all_prev = []
                        for r in range(round_num):
                            all_prev.extend(node.received_messages.get(r, []))
                        attack_count = sum(1 for v in all_prev if v == Decision.ATTACK)
                        value_to_send = Decision.ATTACK if attack_count > len(all_prev)/2 else Decision.RETREAT
                    
                    sent_value = node.send_message(round_num, neighbor_id, value_to_send, self.topology)
                    if sent_value and neighbor_id in self.nodes:
                        self.nodes[neighbor_id].receive_message(round_num, node_id, sent_value)
        
        self.print_round_state(round_num)
    
    def print_round_state(self, round_num: int):
        """Print current state of all nodes"""
        print(f"Round {round_num} State:")
        for node_id, node in sorted(self.nodes.items()):
            msgs = node.received_messages.get(round_num, [])
            msg_str = ", ".join([msg.value for msg in msgs]) if msgs else "None"
            traitor_str = " [TRAITOR]" if node.is_traitor else ""
            print(f"  Node {node_id}{traitor_str}: received [{msg_str}]")
    
    def run_consensus(self, max_rounds: int, initial_value: Decision) -> Dict[int, Decision]:
        """Run full consensus protocol"""
        print("=" * 50)
        print(f"Starting BFT Consensus")
        print(f"Topology: {self.topology}")
        print(f"Traitors: {[nid for nid, node in self.nodes.items() if node.is_traitor]}")
        print(f"Initial value: {initial_value.value}")
        print("=" * 50)
        
        self.set_commander(self.commander_id, initial_value)
        
        for round_num in range(max_rounds):
            self.run_round(round_num)
        
        # Final voting
        print(f"\n--- Final Voting ---")
        decisions = {}
        for node_id, node in sorted(self.nodes.items()):
            node.vote()
            decisions[node_id] = node.decision
            traitor_str = " [TRAITOR]" if node.is_traitor else ""
            print(f"Node {node_id}{traitor_str}: {node.decision.value}")
        
        return decisions
    
    def check_consensus(self, decisions: Dict[int, Decision]) -> bool:
        """Check if consensus conditions are satisfied"""
        loyal_nodes = {nid: decision for nid, decision in decisions.items() 
                      if not self.nodes[nid].is_traitor and nid != self.commander_id}
        
        if not loyal_nodes:
            return True
        
        # IC1: All loyal lieutenants decide same value
        first_decision = next(iter(loyal_nodes.values()))
        ic1_satisfied = all(decision == first_decision for decision in loyal_nodes.values())
        
        # IC2: If commander loyal, all loyal lieutenants decide commander's value
        commander = self.nodes[self.commander_id]
        ic2_satisfied = True
        if not commander.is_traitor:
            ic2_satisfied = all(decision == commander.initial_value for decision in loyal_nodes.values())
        
        print(f"\nConsensus Check:")
        print(f"IC1 (All loyal agree): {ic1_satisfied}")
        print(f"IC2 (Follow loyal commander): {ic2_satisfied}")
        
        return ic1_satisfied and (commander.is_traitor or ic2_satisfied)

# Example test cases
def test_scenarios():
    tester = BFTTester()
    
    print("🧪 TEST 1: Complete Graph, No Traitors")
    # Topology: 0-1-2-3 (complete)
    tester = BFTTester()
    for i in range(4):
        tester.add_node(i)
    for i in range(4):
        for j in range(i+1, 4):
            tester.add_connection(i, j)
    tester.set_commander(0, Decision.ATTACK)
    decisions = tester.run_consensus(max_rounds=2, initial_value=Decision.ATTACK)
    assert tester.check_consensus(decisions)
    
    print("\n" + "="*80 + "\n")
    
    print("🧪 TEST 2: Sparse Graph, Node 1 as Traitor")
    # Topology: 0-1, 1-2, 1-3, 2-3
    tester = BFTTester()
    for i in range(4):
        tester.add_node(i, is_traitor=(i==1))
    tester.add_connection(0, 1)
    tester.add_connection(1, 2)
    tester.add_connection(1, 3)
    tester.add_connection(2, 3)
    tester.set_commander(0, Decision.ATTACK)
    decisions = tester.run_consensus(max_rounds=3, initial_value=Decision.ATTACK)
    tester.check_consensus(decisions)

if __name__ == "__main__":
    test_scenarios()