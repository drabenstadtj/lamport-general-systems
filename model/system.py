from enum import Enum
from typing import List, Dict, Optional
import random


class NodeState(Enum):
    HEALTHY = "HEALTHY"
    CRASHED = "CRASHED"
    BYZANTINE = "BYZANTINE"


class VoteValue(Enum):
    OPEN = "OPEN"
    LOCKED = "LOCKED"


class MessageType(Enum):
    PRE_PREPARE = "PRE_PREPARE"
    PREPARE = "PREPARE"
    COMMIT = "COMMIT"


class SecurityLevel(Enum):
    MAINTENANCE = "MAINTENANCE"
    NORMAL = "NORMAL"


class Message:
    # Represents a message 
    def __init__(self, msg_type: MessageType, sender_id: int, receiver_id: int, 
                 value: VoteValue, round_num: int):
        self.type = msg_type
        self.sender_id = sender_id
        self.receiver_id = receiver_id
        self.value = value
        self.round_num = round_num
    
    def __repr__(self):
        return f"{self.type.value} from Node {self.sender_id} to {self.receiver_id}: {self.value.value}"


class Node:
    # Represents a node in the network
    def __init__(self, node_id: int, initial_state: NodeState = NodeState.HEALTHY):
        self.id = node_id
        self.state = initial_state
    
    def is_healthy(self) -> bool:
        return self.state == NodeState.HEALTHY
    
    def is_crashed(self) -> bool:
        return self.state == NodeState.CRASHED
    
    def is_byzantine(self) -> bool:
        return self.state == NodeState.BYZANTINE
    
    def set_state(self, new_state: NodeState):
        print(f"Node {self.id}: {self.state.value} → {new_state.value}")
        self.state = new_state
    
    def __repr__(self):
        return f"Node({self.id}, {self.state.value})"


class NetworkState:
    # Manages the network of nodes
    def __init__(self, f: int):
        self.f = f  # Fault tolerance
        self.nodes: List[Node] = []
        self.security_level = SecurityLevel.NORMAL
        self.initialize_nodes()
    
    def initialize_nodes(self):
        # Create 3f+1 nodes (for f=1, that's 4 nodes)
        for i in range(3 * self.f + 1):
            # Start some nodes crashed (nodes beyond f start crashed)
            state = NodeState.CRASHED if i > self.f else NodeState.HEALTHY
            self.nodes.append(Node(i, state))
        print(f"Created {len(self.nodes)} nodes (f={self.f})")
        self.print_node_states()
    
    def get_node(self, node_id: int) -> Optional[Node]:
        if 0 <= node_id < len(self.nodes):
            return self.nodes[node_id]
        return None
    
    def get_commander(self) -> Node:
        # Commander is always node 0 for now
        return self.nodes[0]
    
    def count_healthy_nodes(self) -> int:
        return sum(1 for n in self.nodes if n.is_healthy())
    
    def count_crashed_nodes(self) -> int:
        return sum(1 for n in self.nodes if n.is_crashed())
    
    def count_byzantine_nodes(self) -> int:
        return sum(1 for n in self.nodes if n.is_byzantine())
    
    def can_reach_maintenance_level(self) -> bool:
        return self.count_healthy_nodes() >= (3 * self.f + 1)
    
    def check_level_transitions(self):
        if self.security_level == SecurityLevel.NORMAL:
            if self.can_reach_maintenance_level():
                self.security_level = SecurityLevel.MAINTENANCE
                print(f"Security Level: NORMAL to MAINTENANCE")
        elif self.security_level == SecurityLevel.MAINTENANCE:
            if self.count_healthy_nodes() < (3 * self.f + 1):
                self.security_level = SecurityLevel.NORMAL
                print(f"Security Level: MAINTENANCE to NORMAL")
    
    def print_node_states(self):
        print("\nNode States:")
        for node in self.nodes:
            print(f"  {node}")


class ConsensusEngine:
    # Implements the BFT consensus protocol
    def __init__(self, network_state: NetworkState):
        self.network_state = network_state
        self.current_round = 0
        self.failed_rounds_count = 0
        self.failsafe_threshold = 10
        self.failsafe_active = False
        self.current_door_state = VoteValue.LOCKED
        
        # Message storage
        self.pre_prepare_messages: List[Message] = []
        self.prepare_messages: List[Message] = []
        self.commit_messages: List[Message] = []
    
    def run_consensus_round(self, commander_proposal: VoteValue) -> Dict:
        # Run a complete consensus round 
        print(f"\n{'='*50}")
        print(f"CONSENSUS ROUND {self.current_round}")
        print(f"{'='*50}")
        
        # Clear message storage
        self.pre_prepare_messages.clear()
        self.prepare_messages.clear()
        self.commit_messages.clear()
        
        # Check if enough healthy nodes
        healthy_count = self.network_state.count_healthy_nodes()
        required = 2 * self.network_state.f + 1
        
        if healthy_count < required:
            print(f"FAILED: Insufficient healthy nodes ({healthy_count} < {required})")
            self.failed_rounds_count += 1
            self.check_failsafe()
            return {
                "success": False,
                "reason": "Insufficient healthy nodes",
                "phase_reached": "pre-check"
            }
        
        # Check if commander is healthy
        commander = self.network_state.get_commander()
        if not commander.is_healthy():
            print("FAILED: Commander (Node 0) is not healthy")
            self.failed_rounds_count += 1
            self.check_failsafe()
            return {
                "success": False,
                "reason": "Commander is not healthy",
                "phase_reached": "pre-check"
            }
        
        # Phase 1: PRE-PREPARE
        print(f"\n--- Phase 1: PRE-PREPARE ---")
        if not self.phase_1_pre_prepare(commander_proposal):
            self.failed_rounds_count += 1
            self.check_failsafe()
            return {
                "success": False,
                "reason": "Pre-prepare phase failed",
                "phase_reached": "pre-prepare"
            }
        
        # Phase 2: PREPARE
        print(f"\n--- Phase 2: PREPARE ---")
        if not self.phase_2_prepare():
            self.failed_rounds_count += 1
            self.check_failsafe()
            return {
                "success": False,
                "reason": "Prepare phase failed",
                "phase_reached": "prepare"
            }
        
        # Phase 3: COMMIT
        print(f"\n--- Phase 3: COMMIT ---")
        consensus_value = self.phase_3_commit()
        if consensus_value is None:
            self.failed_rounds_count += 1
            self.check_failsafe()
            return {
                "success": False,
                "reason": "Commit phase failed - no consensus",
                "phase_reached": "commit"
            }
        
        # SUCCESS
        print(f"\nCONSENSUS REACHED: {consensus_value.value}")
        self.current_door_state = consensus_value
        self.failed_rounds_count = 0
        self.current_round += 1
        
        return {
            "success": True,
            "agreed_value": consensus_value,
            "phase_reached": "complete",
            "pre_prepare_count": len(self.pre_prepare_messages),
            "prepare_count": len(self.prepare_messages),
            "commit_count": len(self.commit_messages)
        }
    
    def phase_1_pre_prepare(self, proposal: VoteValue) -> bool:
        """Commander broadcasts proposal to all nodes"""
        commander = self.network_state.get_commander()
        
        print(f"Commander (Node 0) proposes: {proposal.value}")
        
        for node in self.network_state.nodes:
            if node.is_crashed():
                continue
            
            received_value = proposal
            
            # Byzantine commander sends different values
            if commander.is_byzantine():
                received_value = random.choice([VoteValue.OPEN, VoteValue.LOCKED])
                print(f"  → Node {node.id} receives: {received_value.value} (Byzantine commander lying!)")
            else:
                print(f"  → Node {node.id} receives: {received_value.value}")
            
            msg = Message(MessageType.PRE_PREPARE, commander.id, node.id, 
                         received_value, self.current_round)
            self.pre_prepare_messages.append(msg)
        
        return len(self.pre_prepare_messages) > 0
    
    def phase_2_prepare(self) -> bool:
        # All nodes broadcast what they received
        print("All nodes broadcast what they received from commander...")
        
        for node in self.network_state.nodes:
            if node.is_crashed():
                continue
            
            # What did this node receive in phase 1?
            received_value = self.get_pre_prepare_value_for_node(node.id)
            if received_value is None:
                continue
            
            # Node broadcasts to all other nodes
            for other_node in self.network_state.nodes:
                if other_node.is_crashed():
                    continue
                
                broadcast_value = received_value
                
                # Byzantine nodes lie
                if node.is_byzantine():
                    broadcast_value = random.choice([VoteValue.OPEN, VoteValue.LOCKED])
                    print(f"  Byzantine Node {node.id} → Node {other_node.id}: {broadcast_value.value} (lying)")
                
                msg = Message(MessageType.PREPARE, node.id, other_node.id, 
                            broadcast_value, self.current_round)
                self.prepare_messages.append(msg)
        
        # Print summary
        open_count = sum(1 for m in self.prepare_messages if m.value == VoteValue.OPEN)
        locked_count = sum(1 for m in self.prepare_messages if m.value == VoteValue.LOCKED)
        print(f"  PREPARE messages: {open_count} for OPEN, {locked_count} for LOCKED")
        
        return len(self.prepare_messages) > 0
    
    def phase_3_commit(self) -> Optional[VoteValue]:
        # Nodes commit to the value they see consensus on
        print("Nodes commit to values they see majority for...")
        
        for node in self.network_state.nodes:
            if node.is_crashed():
                continue
            
            # Count PREPARE messages this node received
            value_counts = self.count_prepare_messages_for_node(node.id)
            
            # Does this node see 2f+1 messages for a value?
            commit_value = None
            if value_counts[VoteValue.OPEN] >= 2 * self.network_state.f + 1:
                commit_value = VoteValue.OPEN
            elif value_counts[VoteValue.LOCKED] >= 2 * self.network_state.f + 1:
                commit_value = VoteValue.LOCKED
            
            if commit_value is not None:
                # Byzantine nodes commit to random values
                if node.is_byzantine():
                    commit_value = random.choice([VoteValue.OPEN, VoteValue.LOCKED])
                
                print(f"  Node {node.id} commits: {commit_value.value}")
                
                # Broadcast commit to all other nodes
                for other_node in self.network_state.nodes:
                    if other_node.is_crashed():
                        continue
                    
                    msg = Message(MessageType.COMMIT, node.id, other_node.id, 
                                commit_value, self.current_round)
                    self.commit_messages.append(msg)
        
        # Final consensus: count COMMIT messages (unique senders only)
        commit_counts = {VoteValue.OPEN: 0, VoteValue.LOCKED: 0}
        counted_senders = set()
        
        for msg in self.commit_messages:
            if msg.sender_id not in counted_senders:
                commit_counts[msg.value] += 1
                counted_senders.add(msg.sender_id)
        
        print(f"  COMMIT messages: {commit_counts[VoteValue.OPEN]} for OPEN, "
              f"{commit_counts[VoteValue.LOCKED]} for LOCKED")
        
        # Need 2f+1 commits for consensus
        if commit_counts[VoteValue.OPEN] >= 2 * self.network_state.f + 1:
            return VoteValue.OPEN
        elif commit_counts[VoteValue.LOCKED] >= 2 * self.network_state.f + 1:
            return VoteValue.LOCKED
        
        return None
    
    def get_pre_prepare_value_for_node(self, node_id: int) -> Optional[VoteValue]:
        # Get what value a specific node received in PRE-PREPARE"""
        for msg in self.pre_prepare_messages:
            if msg.receiver_id == node_id:
                return msg.value
        return None
    
    def count_prepare_messages_for_node(self, node_id: int) -> Dict[VoteValue, int]:
        # Count PREPARE messages a node would see
        counts = {VoteValue.OPEN: 0, VoteValue.LOCKED: 0}
        senders_seen = set()
        
        for msg in self.prepare_messages:
            # Only count one message per sender
            if msg.sender_id not in senders_seen:
                counts[msg.value] += 1
                senders_seen.add(msg.sender_id)
        
        return counts
    
    def check_failsafe(self):
        if self.failed_rounds_count >= self.failsafe_threshold:
            self.trigger_failsafe()
    
    def trigger_failsafe(self):
        self.failsafe_active = True
        print("\nFAILSAFE ACTIVATED - Manual override enabled")


class PlayerActions:
    # Handles player actions on the network
    def __init__(self, network_state: NetworkState, consensus_engine: ConsensusEngine):
        self.network_state = network_state
        self.consensus_engine = consensus_engine
        self.actions_this_round = {"crashes": [], "corrupts": []}
    
    def reboot_node(self, node_id: int) -> Dict:
        # Reboot a crashed node
        node = self.network_state.get_node(node_id)
        
        if not node:
            return {"success": False, "message": "Invalid node ID"}
        
        if not node.is_crashed():
            return {"success": False, "message": f"Node {node_id} is not crashed"}
        
        node.set_state(NodeState.HEALTHY)
        return {"success": True, "message": f"Node {node_id} rebooted successfully"}
    
    def crash_node(self, node_id: int) -> Dict:
        # Crash a node
        node = self.network_state.get_node(node_id)
        
        if not node:
            return {"success": False, "message": "Invalid node ID"}
        
        if node.is_crashed():
            return {"success": False, "message": f"Node {node_id} is already crashed"}
        
        node.set_state(NodeState.CRASHED)
        self.actions_this_round["crashes"].append(node_id)
        
        attack = self.detect_attack()
        return {
            "success": True, 
            "message": f"Node {node_id} crashed",
            "attack_detected": attack
        }
    
    def corrupt_node(self, node_id: int) -> Dict:
        # Corrupt a node to become Byzantine
        node = self.network_state.get_node(node_id)
        
        if not node:
            return {"success": False, "message": "Invalid node ID"}
        
        if not node.is_healthy():
            return {"success": False, "message": f"Node {node_id} must be healthy to corrupt"}
        
        node.set_state(NodeState.BYZANTINE)
        self.actions_this_round["corrupts"].append(node_id)
        
        attack = self.detect_attack()
        return {
            "success": True, 
            "message": f"Node {node_id} corrupted",
            "attack_detected": attack
        }
    
    def command_door(self, value: VoteValue) -> Dict:
        # Command the door directly (requires maintenance level)
        if self.network_state.security_level != SecurityLevel.MAINTENANCE:
            return {
                "success": False,
                "message": "Must be at Maintenance level to command door"
            }
        
        self.consensus_engine.current_door_state = value
        door_opened = value == VoteValue.OPEN
        
        return {
            "success": True,
            "message": f"Door commanded to {value.value}",
            "door_opened": door_opened,
            "win_type": "restoration" if door_opened else None
        }
    
    def exploit_door(self) -> Dict:
        # Exploit failsafe to force door open
        if not self.consensus_engine.failsafe_active:
            return {
                "success": False,
                "message": "Failsafe not active - cannot exploit door"
            }
        
        self.consensus_engine.current_door_state = VoteValue.OPEN
        
        return {
            "success": True,
            "message": "Door exploited (failsafe)",
            "door_opened": True,
            "win_type": "sabotage"
        }
    
    def detect_attack(self) -> bool:
        # Detect if an attack pattern is occurring
        crash_count = len(self.actions_this_round["crashes"])
        corrupt_count = len(self.actions_this_round["corrupts"])
        total_byzantine = self.network_state.count_byzantine_nodes()
        
        if crash_count >= 2:
            print("ATTACK DETECTED: 2+ crashes in one round")
            return True
        
        if corrupt_count >= 2:
            print("ATTACK DETECTED: 2+ corruptions in one round")
            return True
        
        if total_byzantine > self.network_state.f:
            print(f"ATTACK DETECTED: {total_byzantine} Byzantine nodes "
                  f"(max tolerable: {self.network_state.f})")
            return True
        
        # Check if commander was targeted
        commander = self.network_state.get_commander()
        if not commander.is_healthy():
            if 0 in self.actions_this_round["crashes"] or 0 in self.actions_this_round["corrupts"]:
                print("ATTACK DETECTED: Commander node targeted")
                return True
        
        return False
    
    def reset_round_tracking(self):
        self.actions_this_round = {"crashes": [], "corrupts": []}




def demo_f1_restoration_path():
    # Demonstration with f=1 (4 nodes, tolerates 1 Byzantine)
    print("="*60)
    print("DEMO: f=1 (4 nodes) - RESTORATION PATH")
    print("="*60)
    
    f = 1
    network = NetworkState(f)
    consensus = ConsensusEngine(network)
    actions = PlayerActions(network, consensus)
    
    # Initial state: 2 healthy, 2 crashed
    print("\nInitial configuration: 2 healthy nodes, 2 crashed nodes")
    print("Need all 4 nodes healthy to reach MAINTENANCE level")
    
    # Reboot crashed nodes
    print("\n" + "="*60)
    print("ACTION: Rebooting Node 2")
    print("="*60)
    result = actions.reboot_node(2)
    print(result["message"])
    
    print("\n" + "="*60)
    print("ACTION: Rebooting Node 3")
    print("="*60)
    result = actions.reboot_node(3)
    print(result["message"])
    
    network.print_node_states()
    network.check_level_transitions()
    
    # Run consensus with all nodes healthy
    print("\nRunning consensus with all 4 nodes healthy...")
    result = consensus.run_consensus_round(VoteValue.OPEN)
    print(f"\nDoor state: {consensus.current_door_state.value}")
    print(f"Security level: {network.security_level.value}")
    
    # Command door at maintenance level
    print("\n" + "="*60)
    print("ACTION: Commanding door to OPEN (at MAINTENANCE level)")
    print("="*60)
    result = actions.command_door(VoteValue.OPEN)
    print(result["message"])
    if result.get("door_opened"):
        print(f"\nWIN - {result['win_type'].upper()} PATH")
    
    print(f"\nFinal door state: {consensus.current_door_state.value}")


def demo_f2_byzantine_attack():
    # Demonstration with f=2 (7 nodes, tolerates 2 Byzantine)
    print("\n\n" + "="*60)
    print("DEMO: f=2 (7 nodes) - BYZANTINE ATTACK SCENARIO")
    print("="*60)
    
    f = 2
    network = NetworkState(f)
    consensus = ConsensusEngine(network)
    actions = PlayerActions(network, consensus)
    
    # Initial state: 3 healthy (0,1,2), 4 crashed (3,4,5,6)
    print("\nInitial configuration: 3 healthy nodes, 4 crashed nodes")
    print("Need all 7 nodes healthy to reach MAINTENANCE level")
    
    # Reboot some nodes
    print("\n" + "="*60)
    print("ACTION: Rebooting Nodes 3, 4, 5, 6")
    print("="*60)
    for i in [3, 4, 5, 6]:
        result = actions.reboot_node(i)
        print(f"  {result['message']}")
    
    network.print_node_states()
    network.check_level_transitions()
    
    # Run initial consensus with all healthy
    print("\nRunning consensus round 1 with all 7 nodes healthy...")
    result = consensus.run_consensus_round(VoteValue.OPEN)
    if result["success"]:
        print(f"Consensus successful: {result['agreed_value'].value}")
    
    # Now corrupt a node (within tolerance)
    print("\n" + "="*60)
    print("ACTION: Corrupting Node 1 (Byzantine)")
    print("="*60)
    result = actions.corrupt_node(1)
    print(result["message"])
    if result["attack_detected"]:
        print("Attack detected!")
    else:
        print("  Within fault tolerance (f=2, can tolerate 2 Byzantine)")
    
    network.print_node_states()
    actions.reset_round_tracking()
    
    # Run consensus with 1 Byzantine node
    print("\nRunning consensus round 2 with 1 Byzantine node...")
    result = consensus.run_consensus_round(VoteValue.LOCKED)
    if result["success"]:
        print(f"Consensus successful despite Byzantine node: {result['agreed_value'].value}")
    
    # Corrupt another node
    print("\n" + "="*60)
    print("ACTION: Corrupting Node 2 (Byzantine)")
    print("="*60)
    result = actions.corrupt_node(2)
    print(result["message"])
    if result["attack_detected"]:
        print("Attack detected!")
    else:
        print("  Still within tolerance (2 Byzantine nodes, f=2)")
    
    network.print_node_states()
    actions.reset_round_tracking()
    
    # Run consensus with 2 Byzantine nodes (at the limit)
    print("\nRunning consensus round 3 with 2 Byzantine nodes (at tolerance limit)...")
    result = consensus.run_consensus_round(VoteValue.OPEN)
    if result["success"]:
        print(f"Consensus still possible: {result['agreed_value'].value}")
    else:
        print(f"Consensus failed: {result['reason']}")
    
    # Try to corrupt a third node (exceed tolerance)
    print("\n" + "="*60)
    print("ACTION: Attempting to corrupt Node 3 (would exceed tolerance)")
    print("="*60)
    result = actions.corrupt_node(3)
    print(result["message"])
    if result["attack_detected"]:
        print("  ATTACK DETECTED! More than f=2 Byzantine nodes!")
    
    network.print_node_states()
    actions.reset_round_tracking()
    
    # Try consensus with 3 Byzantine nodes (should fail)
    print("\nRunning consensus round 4 with 3 Byzantine nodes (exceeds tolerance)...")
    result = consensus.run_consensus_round(VoteValue.LOCKED)
    if result["success"]:
        print(f"Consensus: {result['agreed_value'].value}")
    else:
        print(f"Consensus likely to fail: {result['reason']}")
        print(f"Failed rounds: {consensus.failed_rounds_count}/{consensus.failsafe_threshold}")


def demo_f1_sabotage_path():
    # Demonstration with f=1 showing the sabotage path
    print("\n\n" + "="*60)
    print("DEMO: f=1 (4 nodes) - SABOTAGE PATH (Failsafe Exploit)")
    print("="*60)
    
    f = 1
    network = NetworkState(f)
    consensus = ConsensusEngine(network)
    actions = PlayerActions(network, consensus)
    
    print("\nGoal: Trigger failsafe by causing 10 failed consensus rounds")
    print("Strategy: Keep commander (Node 0) crashed\n")
    
    # Crash the commander
    print("="*60)
    print("ACTION: Crashing Commander (Node 0)")
    print("="*60)
    result = actions.crash_node(0)
    print(result["message"])
    network.print_node_states()
    
    # Run multiple failed consensus rounds
    print("\nRunning consensus rounds with crashed commander...")
    for i in range(10):
        actions.reset_round_tracking()
        result = consensus.run_consensus_round(VoteValue.OPEN)
        print(f"\nRound {i+1}: {result['reason']} (Failed: {consensus.failed_rounds_count}/10)")
        
        if consensus.failsafe_active:
            break
    
    # Exploit the failsafe
    if consensus.failsafe_active:
        print("\n" + "="*60)
        print("ACTION: Exploiting Failsafe to Force Door Open")
        print("="*60)
        result = actions.exploit_door()
        print(result["message"])
        if result.get("door_opened"):
            print(f"\nWIN - {result['win_type'].upper()} PATH")
        print(f"\nFinal door state: {consensus.current_door_state.value}")


def main():
    """Run all demonstrations"""
    # Demo 1: f=1 restoration path (normal operation)
    demo_f1_restoration_path()
    
    # Demo 2: f=2 Byzantine attack scenarios
    demo_f2_byzantine_attack()
    
    # Demo 3: f=1 sabotage path (failsafe exploit)
    demo_f1_sabotage_path()
    
    print("\n" + "="*60)
    print("All demonstrations complete!")
    print("="*60)


if __name__ == "__main__":
    # Run all demos
    main()
    
    # individual demos:
    # demo_f1_restoration_path()
    # demo_f2_byzantine_attack()
    # demo_f1_sabotage_path()
