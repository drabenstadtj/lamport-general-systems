# BFT System Refactoring Summary

## What Changed

Your BFT system has been refactored from a **centralized/god-object** architecture to an **agent-based** architecture where each node makes independent decisions.

---

## New Architecture

### Before (Centralized)
```
ConsensusEngine (GOD OBJECT - 357 lines)
├─ Orchestrates all 3 phases
├─ Decides what each node should do
├─ Simulates all message passing
├─ Counts votes for every node
└─ Determines consensus centrally

BFTNode (DUMB DATA - 68 lines)
├─ Just holds id, state
├─ Has signals (mostly unused)
└─ No decision-making logic
```

### After (Agent-Based)
```
NetworkManager (FACILITATOR - ~220 lines)
├─ Routes messages between nodes
├─ Tracks global consensus
├─ Manages failsafe & security levels
└─ Coordinates rounds (but doesn't make decisions)

BFTNodeAgent (AUTONOMOUS AGENT - ~270 lines)
├─ Receives messages from other nodes
├─ Maintains own message inbox
├─ Makes own voting decisions
├─ Broadcasts own messages
└─ Emits consensus when reached independently
```

---

## New Files Created

### 1. `scripts/system/bft_node_agent.gd`
**Replaces:** `node.gd` (which was just a data container)

**What it does:**
- Each node is now autonomous and intelligent
- Nodes have their own inboxes for PRE-PREPARE, PREPARE, and COMMIT messages
- Nodes independently decide when to:
  - Send PREPARE (after receiving PRE-PREPARE with 2f+1 support)
  - Send COMMIT (after seeing quorum of PREPAREs)
  - Declare consensus (after seeing quorum of COMMITs)

**Key methods:**
```gd
receive_pre_prepare(msg)  # Phase 1: Receive commander proposal
receive_prepare(msg)      # Phase 2: Receive peer votes
receive_commit(msg)       # Phase 3: Receive peer commits
broadcast_proposal_as_commander()  # Commander initiates consensus
```

**Byzantine behavior:**
- Nodes apply Byzantine logic themselves
- `_apply_byzantine_behavior()` flips values if node is Byzantine
- Byzantine commander sends different values to different nodes

### 2. `scripts/system/network_manager.gd`
**Replaces:** Both `consensus_engine_classic.gd` and `consensus_engine_adaptive.gd`

**What it does:**
- Creates and manages all BFTNodeAgent instances
- Routes messages between nodes via `_on_node_sent_message(msg)`
- Tracks when global consensus is reached
- Manages failsafe and security levels
- Much simpler than old engines (~220 lines vs 600+ lines combined)

**Key methods:**
```gd
run_consensus_round(proposal)  # Initiates consensus
get_node(node_id)             # Access individual nodes
count_healthy_nodes()         # Network health
check_level_transitions()     # Security level updates
```

---

## Modified Files

### 3. `scripts/autoload/game_manager.gd`
**Changes:**
- Replaced `network_state: NetworkState` with `network_manager: NetworkManager`
- Removed `consensus_engine` variable
- Updated `initialize_game()` to create NetworkManager
- Updated `run_consensus_manually()` to use NetworkManager
- All node access now through `network_manager.get_node()`

### 4. `scripts/system/player_action_handler.gd`
**Changes:**
- Replaced `network_state` and `consensus_engine` with single `network_manager`
- Updated all methods to use `network_manager.get_node()`
- Updated door commands to use `network_manager.current_door_state`
- Added `_count_byzantine_nodes()` helper method

---

## How Consensus Works Now

### Old Way (Centralized)
```
1. ConsensusEngine.run_consensus_round()
2. Engine orchestrates Phase 1: creates all PRE-PREPARE messages
3. Engine orchestrates Phase 2: creates all PREPARE messages
4. Engine orchestrates Phase 3: creates all COMMIT messages
5. Engine counts votes and declares consensus
```

### New Way (Agent-Based)
```
1. NetworkManager.run_consensus_round(proposal)
2. Commander node broadcasts PRE-PREPARE to all nodes
3. Each node receives PRE-PREPARE:
   → Immediately broadcasts PREPARE with what it received
4. Each node receives enough PREPAREs (2f+1):
   → Broadcasts COMMIT to all nodes
5. Each node receives enough COMMITs (2f+1):
   → Emits consensus_reached signal independently
6. NetworkManager listens for consensus_reached:
   → When 2f+1 nodes agree, declares global consensus
```

**The key difference:** Nodes make decisions themselves based on their inbox, not based on a central orchestrator telling them what to do.

---

## Benefits of New Architecture

### 1. **More Realistic**
- Mirrors real distributed systems where nodes are independent
- Each node only sees its own messages
- No centralized god-object that knows everything

### 2. **Easier to Understand**
- **BFTNodeAgent:** "What does ONE node do when it receives a message?"
- **NetworkManager:** "How do messages get delivered?"
- Old way: "What does the ENTIRE SYSTEM do?" (much harder!)

### 3. **Better for Gameplay**
- Each NodeTerminal shows what ITS node is thinking
- Byzantine attacks are clearer (you see the node lying in real-time)
- Players understand "each node decides independently"

### 4. **Easier to Test**
```gd
# Test a single node's logic in isolation
var node = BFTNodeAgent.new(1, 1)
node.receive_prepare(msg1)
node.receive_prepare(msg2)
node.receive_prepare(msg3)
assert(node.has_sent_commit)  # Did it commit?
```

### 5. **Less Code**
- Eliminated ~380 lines of duplicate code
- Single agent-based implementation replaces both Classic and Adaptive engines
- No more duplicate deduplication logic

### 6. **Easier to Extend**
Want to add message delays or drops?
```gd
func _deliver_message(receiver, msg):
    if randf() < 0.1:
        return  # 10% message loss
    await get_tree().create_timer(randf() * 0.5).timeout  # Random delay
    # Then deliver...
```

Want to add view changes (commander election)?
```gd
func detect_commander_failure():
    if received_pre_prepares.size() == 0:
        # No message from commander, elect new one
        message_sent.emit(ViewChangeMessage.new(id, current_round + 1))
```

---

## What's Removed

### Old Files (Can be deleted or kept for reference)
- `scripts/system/consensus_engine_classic.gd` (255 lines) - **No longer used**
- `scripts/system/consensus_engine_adaptive.gd` (357 lines) - **No longer used**
- `scripts/system/network_state.gd` (62 lines) - **No longer used** (functionality moved to NetworkManager)
- `scripts/system/node.gd` (68 lines) - **Replaced by** `bft_node_agent.gd`

**Total removed:** ~742 lines
**Total added:** ~490 lines
**Net reduction:** ~250 lines while gaining more features

---

## Migration Checklist

- [x] Create BFTNodeAgent with autonomous decision-making
- [x] Create NetworkManager for message routing
- [x] Update GameManager to use NetworkManager
- [x] Update PlayerActionHandler to use NetworkManager
- [ ] Test the refactored system in-game
- [ ] Verify NodeTerminals display correctly
- [ ] Test Byzantine node behavior
- [ ] Test consensus with various node states
- [ ] (Optional) Delete old consensus engine files

---

## Testing the New System

### Quick Test
1. Run your game
2. Press `-` or `=` to trigger consensus
3. Watch the NodeTerminals - you should see:
   - `← PRE-PREP: OPEN from Node 0`
   - `→ PREPARE: OPEN (broadcast)`
   - `→ COMMIT: OPEN (broadcast)`
   - `✓ DECIDED: OPEN`

### Byzantine Test
1. Corrupt a node (make it Byzantine)
2. Run consensus
3. Watch the corrupted node's terminal:
   - It should send different values than it received
   - Other nodes should still reach consensus (if f tolerance allows)

### Failsafe Test
1. Crash enough nodes to prevent consensus
2. Try consensus 10 times (failsafe_threshold)
3. Failsafe should activate
4. Use exploit_door() to force door open

---

## Key Differences in Behavior

### Message Logging
- **Old:** Adaptive engine logged messages, Classic didn't
- **New:** ALL nodes log all messages to their terminals consistently

### Byzantine Behavior
- **Old:** Classic used random flips, Adaptive used deterministic flips
- **New:** Deterministic flips (Byzantine nodes always flip the value)

### Return Values
- **Old:** Different return dictionaries for Classic vs Adaptive
- **New:** Consistent return schema:
  ```gd
  {
    "success": bool,
    "agreed_value": Enums.VoteValue,  # if success
    "reason": String,                 # if failed
    "phase_reached": String,
    "decided_nodes": int,
    "votes": {OPEN: count, LOCKED: count}
  }
  ```

---

## Troubleshooting

### "Could not find type NetworkManager"
- Reload the Godot project (Project → Reload Current Project)
- The new classes need to be registered

### Nodes not making decisions
- Check that nodes are healthy (not crashed)
- Check that there are 2f+1 healthy nodes minimum
- Add debug prints in `receive_prepare()` to see message flow

### Messages not appearing in terminals
- Verify `link_game_object(terminal)` is called in GameManager
- Check that terminals have `add_log()` method
- Nodes emit signals which terminals should be listening to

---

## Questions?

**Q: Can I still use the old consensus engines?**
A: Yes, but you'd need to update GameManager back. The new system is recommended.

**Q: How do I switch back if something breaks?**
A: Revert GameManager.gd and PlayerActionHandler.gd to use NetworkState and ConsensusEngine classes.

**Q: Can I customize Byzantine behavior?**
A: Yes! Edit `BFTNodeAgent._apply_byzantine_behavior()` to implement different attack strategies.

**Q: Where's the OM(m) algorithm now?**
A: The agent-based system currently implements PBFT (3-phase commit). The OM(m) multi-round relay can be added as an extension.

---

## Next Steps

1. **Test the system** - Run the game and verify consensus works
2. **Clean up** - Optionally delete old engine files
3. **Extend** - Add new features like:
   - View changes (commander election)
   - Message delays/drops
   - Network partitions
   - Advanced Byzantine strategies
   - Performance metrics

The agent-based architecture makes all of these much easier to implement!
