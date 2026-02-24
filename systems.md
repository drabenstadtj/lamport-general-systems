# System Design Document

- [Network System](#2-network-system)
- [Terminal System](#3-terminal-system)
- [Robot AI System](#4-robot-ai-system)
- [Level & Scene System](#5-level--scene-system)

---

## 2. Network System

### Overview

The network system simulates the **Byzantine Generals Problem**. A set of server nodes must agree on a single value (`OPEN` or `LOCKED`) even if some nodes are lying or offline. The player manipulates node states and message routing to influence the outcome of consensus rounds.

The core constraint: consensus can tolerate at most `f` Byzantine nodes if there are at least `3f + 1` total nodes.

### Architecture

```
NetworkManager  (scene node, in group "network_manager")
├── NetworkState        (RefCounted — holds all data)
│   └── NetworkNode[]   (RefCounted — one per server)
└── ConsensusEngineAdaptive  (RefCounted — runs the algorithm)
```

`NetworkManager` is the public API — everything else (terminals, buttons, robot triggers) calls into it. `NetworkState` and `ConsensusEngineAdaptive` have no scene dependencies.

### NetworkNode

**Script:** `scripts/network/network_node.gd`

Represents one logical server.

**States:**

- `HEALTHY` — participates honestly in consensus
- `CRASHED` — offline, does not send or receive messages, recoverable via `reboot`
- `BYZANTINE` — online but malicious, always flips its vote, cannot be powered down
- `POWERED_DOWN` — manually switched off, recoverable via `power_on`

**Virtual Filesystem:**
Each node has an in-memory filesystem at `/home/user/logs/` with:

- `consensus.log` — records each round: proposal, result, confidence, state changes
- `messages.log` — records every message sent, received, blocked, or spoofed

These are written automatically and readable via terminal commands.

**Message Spoofing:**
A node can be configured to send a different value to specific targets using `set_spoof(target_id, value)`. This makes a node behave Byzantine without being flagged as `BYZANTINE` state — `BYZANTINE` state flips all votes automatically; spoofing is a targeted manual override.

### NetworkState

**Script:** `scripts/network/network_state.gd`

Owns the node array and all cross-node data. Does not run the algorithm.

**Responsibilities:**

- Node array storage and lookup
- **Link blocking** — specific directed links can be blocked for N rounds, preventing message delivery
- **Security level** — tracks whether the network has enough healthy nodes, checked after every player action
- **Anomaly detection** — builds a suspicion score per node based on observed misbehaviour

**Security Levels:**

- `MAINTENANCE` — at least `3f + 1` healthy nodes
- `NORMAL` — fewer than `3f + 1` healthy nodes

Transitions emit `security_level_changed` after every node state change.

**Suspicion Scores:**
Each suspicious event adds to a per-node score:

- Message blocked: +1
- Inconsistent vote: +2
- Spoofed message sent: +3
- Byzantine behaviour: +3

Alert levels based on score:

- `NORMAL` — 0–2
- `ELEVATED` — 3–5
- `HIGH` — 6–9
- `CRITICAL` — 10+

These are readable via the `alerts` and `suspicion` terminal commands.

### ConsensusEngineAdaptive

**Script:** `scripts/network/consensus_engine_adaptive.gd`

Runs the BFT consensus algorithm, called once per round by `NetworkManager.run_consensus()`.

**Algorithm — Oral Messages (OM):**

Phase 1 (PRE-PREPARE): Node 0 (the commander) broadcasts its proposal to all non-crashed nodes. Blocked links drop the message; spoof overrides replace the value.

Phase 2 (PREPARE / relay): Each non-crashed node that received a PRE-PREPARE re-broadcasts its value to all other nodes. Byzantine nodes flip the value before sending. Repeated `m` times for `OM(m)` depth.

Phase 3 (COMMIT / decision): Each node tallies all messages it received. Majority wins; ties go to `LOCKED`. Byzantine nodes flip their reported vote before submitting.

**Adaptive Multi-Attempt:**
If the first attempt doesn't reach the confidence threshold, the engine escalates:

- Attempt 1 — OM(0), needs 80% confidence
- Attempt 2 — OM(1), needs 75% confidence
- Attempt 3 — OM(2), needs 70% confidence
- Attempt 4 — OM(3), needs 65% confidence

Early failure: if any attempt sees ≥70% confidence on the wrong value, the round fails immediately rather than escalating.

Failsafe: after 10 consecutive failed rounds, `failsafe_active` is set (manual override mode, implementation TBD).

**Return value from `run_consensus()`:**

- `success` — bool
- `agreed_value` — the agreed value if successful
- `consensus` — majority value regardless of success
- `confidence` — 0.0–1.0
- `rounds_used` — int
- `reason` — failure reason string
- `attempts` — per-attempt summaries
- `blocked_messages`, `pre_prepare_messages`, `prepare_messages`, `commit_messages` — for terminal display and logging

### NetworkManager

**Script:** `scripts/network/network_manager.gd`
**Group:** `"network_manager"`

The public-facing scene node. All external systems call into this.

**Initialisation:**
On scene load, call `initialize_from_scene()`. It reads config from the `"network_config"` group node, scans the scene for all `"server"` group nodes, validates `physical_count >= 3f + 1`, then constructs `NetworkState` and `ConsensusEngineAdaptive`.

**Node Action API:**
All actions call `_advance_turn()` after completing, which checks security level and increments the turn counter.

- `crash_node(id)` — sets node to `CRASHED`
- `reboot_node(id)` — recovers a `CRASHED` node to `HEALTHY`
- `corrupt_node(id)` — sets a `HEALTHY` node to `BYZANTINE`
- `power_off_node(id)` — sets node to `POWERED_DOWN` (not allowed on `BYZANTINE` nodes)
- `power_on_node(id)` — recovers a `POWERED_DOWN` node to `HEALTHY`

**Signals:**

- `network_initialized` — setup complete
- `node_state_changed(id, old, new)` — any node changes state
- `consensus_started(proposal)` — round begins
- `consensus_completed(result)` — round ends
- `message_blocked(from, to, type)` — a message was dropped
- `turn_completed(turn_number)` — after any player action
- `security_level_changed(old, new)` — security level transitions
- `game_won(win_type)` — OPEN consensus achieved

---

## 3. Terminal System

### Overview

Physical terminal props placed in the game world. The player approaches a terminal, presses the interact key, and the camera locks to the terminal screen. A full Unix-like CLI is presented for directly manipulating the network.

**Files:**

- `scripts/interaction/terminal.gd` — the world prop (interaction, camera positioning)
- `scripts/ui/terminal_interface.gd` — the CLI logic (commands, rendering, input)
- `scenes/props/network/terminal.tscn` — the scene

### Terminal World Prop

`Terminal` (`Node3D`) contains:

- An `Interactable` area that shows a prompt when the player faces it
- A `CameraPosition` and `CameraLookAt` marker for the camera lock-in
- A `SubViewport` containing the `TerminalUI` control

On interact, the player's controller hands off to terminal-viewing mode. On interact again (or escape), control returns to the player.

Each terminal can be pre-assigned a `default_node_id` — if set, it auto-connects to that node on startup, useful for placing terminals next to their server rack.

### Terminal UI / CLI

`TerminalUI` (`Control`) manages all command processing. It holds a reference to the scene's `NetworkManager` and tracks the currently connected node via `controlled_node_id` / `connected_node`.

**Connection Model:**
The player connects to a node with `connect <id>` (analogous to SSH). While connected:

- The filesystem displayed is that node's virtual filesystem
- Node-control commands act on that node
- Link and spoof commands act from that node

The prompt reflects the connection: `user@node2:~/logs$`

**Filesystem Commands:**

- `ls [path]` — list directory contents
- `cd <path>` — change directory (supports `..`, absolute and relative paths)
- `pwd` — print working directory
- `cat <file>` — print file contents
- `tail [-n N] <file>` — print last N lines (default 10)
- `clear` — clear terminal output

**Node Control** _(requires connection)_

- `status` — show this node's current state
- `reboot` — recover a crashed node
- `crash` — crash this node
- `corrupt` — set this node to BYZANTINE

**Network:**

- `network` — show all nodes and their states
- `connect <id>` — connect to a node
- `disconnect` — disconnect from current node
- `consensus <OPEN|LOCKED>` — run a consensus round with the given proposal

**Link Manipulation** _(requires connection — acts from this node)_

- `block <target> [rounds]` — block outgoing messages to target for N rounds (default 1)
- `unblock <target>` — remove a link block
- `links` — list all active link blocks

**Message Spoofing** _(requires connection)_

- `spoof <target> <OPEN|LOCKED>` — make this node send a false value to target
- `unspoof [target]` — clear spoof (omit target to clear all)
- `spoofs` — list active spoofs on this node

**Detection:**

- `alerts` — show network alert level and recent anomalies
- `suspicion` — show per-node suspicion scores as a bar graph

**UX Features:**

- Tab completion for command names and filesystem paths
- Up/down arrow command history
- Auto-scroll to bottom after each command; PageUp/PageDown and scroll wheel for history
- Coloured output for node states, consensus results, and alerts

---

## 4. Robot AI System

### Overview

Humanoid security robots patrol the facility using a hierarchical state machine, shared sensory components, and a global director that manages overall threat level.

**Files:**

- `scripts/autoload/ai_director.gd` — global manager (autoload)
- `scripts/ai/robot.gd` — per-robot controller
- `scripts/player_controller/robot/` — individual states
- `scripts/player_controller/robot/sensory_component.gd` — vision and hearing

### AIDirector

**Script:** `scripts/autoload/ai_director.gd`
**Type:** Autoload (singleton)

**Registration & persistence:**
When a robot enters the scene it calls `AIDirector.register_robot(self)`. The director attempts to load saved state from `user://robots/<level_name>/<robot_id>.tres`. If found, position, rotation, and `is_active` are restored. On level transition (`clear_level()`), all states are saved to disk.

**Threat meter:**
A float (0–100, default 50) representing facility alertness. Updated every frame based on active robot states.

**Hinting:**
When threat falls below the threshold (default 20), the director selects the most dormant robot (highest `dormant_time`) and sends it to patrol near the player. A 10-second cooldown prevents rapid re-hints.

**Sound propagation:**
`AIDirector.emit_sound(position, volume)` broadcasts a hearing event to all registered robots' `SensoryComponent`s. Any game event that makes noise (server crash, door interaction) calls this.

### Robot

**Script:** `scripts/ai/robot.gd`
**Type:** `CharacterBody3D`

The physical robot character in the scene. Drives movement and animation; delegates AI decisions entirely to the state machine.

**Navigation:**
Uses `NavigationAgent3D` for pathfinding. `navigate_to(target)` sets the destination; `_physics_process` drives movement toward the next path position and smoothly rotates the body using `basis.slerp`.

**Animation:**
`get_move_anim(move_anim, idle_anim)` selects the correct animation based on current velocity and facing angle — returns `Turn90_L` or `Turn90_R` when the robot needs to turn more than 60° to align with its movement direction.

**Debug:**
A floating `Label3D` billboard above the robot displays the current state machine state name.

**Exports:**

- `id` — robot identifier
- `move_speed`, `hunt_move_speed`, `turn_speed` — movement parameters
- `patrol_points: Array[PatrolPoint]` — ordered list of patrol waypoints
- `hostile` — if false, the robot ignores the player entirely

### State Machine

States are in `scripts/player_controller/robot/`. Each state has `enter()`, `exit()`, `update(delta)`, and `physics_update(delta)`. `actor` refers to the owning `Robot`.

**Patrol:**
On entry, navigates to the current patrol point (or a random nav-mesh point if none assigned). When navigation finishes, advances to the next patrol point and navigates there. Increments `actor.dormant_time` each frame. Transitions to Investigate when `SensoryComponent.has_detection` is true.

**Investigate:**
Moves toward the last detected position to confirm the threat. Wanders nearby while searching if navigation finishes and no detection. Resets on re-entry (15s timer, zero visual confidence). Transitions to Hunt on confirmed visual detection. Transitions back to Patrol if the timer expires.

**Hunt:**
Sets movement speed to `hunt_move_speed` on entry. Navigates to the player's live position while in line-of-sight; falls back to `last_detected_position` when LOS is lost. Attack: when the player is within `attack_range` and in LOS, plays a 3-phase animation sequence (`PunchKick_Enter` → `Punch_Jab` → `PunchKick_Exit`) and stops moving. Transitions back to Investigate if LOS is lost for 15 seconds.

**Flee:**
Moves away from the player. Currently a stub.

### SensoryComponent

**Script:** `scripts/player_controller/robot/sensory_component.gd`

Handles vision and hearing. Does nothing if the owning robot's `hostile` flag is false.

**Vision:** A raycast (`sightline`) aimed at the player. `visual_confidence` builds while the player is in LOS; when it crosses the threshold, `is_threat_confirmed` is set. `has_detection` is true while the player is visible.

**Hearing:** `hear_sound(position, volume)` is called by `AIDirector.emit_sound()`. Volume is attenuated by distance. If the result exceeds the hearing threshold, the robot's investigation target is set to the sound origin.

---

## 5. Level & Scene System

### Overview

The game is a sequence of discrete levels, each with its own geometry, network configuration, and robot placement. The `SceneManager` autoload handles transitions.

### Per-Level Network Setup

Each level has:

- A `NetworkManager` node with a `NetworkConfig` child (sets `f_value` and `network_id`)
- One or more `ServerRack` nodes containing `Server` nodes (each with a unique `node_id`)
- One or more `Terminal` nodes, optionally pre-assigned to a node via `default_node_id`

On scene ready, the level script calls `network_manager.initialize_from_scene()` which auto-discovers all servers in the scene.

### Robot Persistence

Robot state (position, rotation, `is_active`) persists across scene transitions via `user://robots/<level_name>/<robot_id>.tres`. A robot the player disabled in a previous visit to a room stays disabled on return.

`AIDirector.clear_level()` must be called before any scene transition to flush current state to disk and clear the in-memory robot registry.
