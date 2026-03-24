# Subnetwork 1 Test Scenarios

**Starting state:** Node 0 HEALTHY, Node 1 HEALTHY, Node 2 BYZANTINE, Node 3 CRASHED, Node 4 POWERED DOWN
**Win condition:** `consensus OPEN` achieves agreement
**Pre-check:** healthy >= 3 AND node 0 must be healthy
**Confidence:** majority_votes / total_participating (Byzantine nodes always flip their vote)
**Thresholds:** attempt 1 = 80%, attempt 2 = 75%, attempt 3 = 70%, attempt 4 = 65%

---

## 1. Minimal Restore — Power Button Only
Nodes 0, 1, 4 healthy. 4 participating (3 HEALTHY + 1 BYZANTINE).
Votes: OPEN=3, LOCKED=1 → 75% → fails attempt 1 (80%), passes attempt 2 (75%).

1. Press power button on node 4
2. `consensus OPEN`
3. **Expected: passes on attempt 2**

---

## 2. Minimal Restore — Terminal Only
Node 4 is POWERED DOWN — test whether `connect` works on it.
Node 3 is CRASHED — connectable, can be rebooted. Same vote math as scenario 1.

1. `connect 4` — test if powered-down node is connectable
2. `connect 3` → `reboot`
3. `consensus OPEN`
4. **Expected: connect 4 fails. With node 3 rebooted: same 75% → passes attempt 2**

---

## 3. Full Restore
All 5 nodes participating: OPEN=4, LOCKED=1 → 80% → passes attempt 1.

1. Press power button on node 4
2. `connect 3` → `reboot`
3. `consensus OPEN`
4. **Expected: passes on attempt 1 (verified)**

---

## 4. Block Byzantine Before Consensus
Blocking node 2's links prevents its LOCKED relay in OM(1) reaching honest nodes,
but node 2 still participates and reports LOCKED in the final tally.
Vote counts are unchanged — blocking only affects the relay phase, not final reported votes.

1. Power on node 4
2. `connect 0` → `block 2 99`
3. `consensus OPEN`
4. **Expected: same result as scenario 1 — blocking has no effect on final vote counts**

---

## 5. Spoof Node 2 Outgoing
`spoof X OPEN` from node 2 makes node 2 send OPEN in relay to node X, reinforcing honest
nodes' OPEN decisions. However node 2's final reported vote is always flipped to LOCKED
regardless of spoofing — spoof only affects relay messages, not the final vote.

1. Power on node 4
2. `connect 2` → `spoof 0 OPEN`, `spoof 1 OPEN`, `spoof 4 OPEN`
3. `consensus OPEN`
4. **Expected: same vote counts as scenario 1 — spoof doesn't change final reported vote**

---

## 6. Self-Inflicted Damage
Crashing node 1 drops healthy count to 1 — below pre-check of 3.
Recovery requires restoring 2 nodes before consensus can run.

1. `connect 1` → `crash`
2. `consensus OPEN` — expected pre-check failure
3. Power on node 4 + `connect 3` → `reboot`
4. `consensus OPEN`
5. **Expected: step 2 fails. After recovery: 3 healthy → passes attempt 2**

---

## 7. Baseline — No Restore
Starting state has only 2 healthy nodes, below pre-check of 3.

1. `consensus OPEN` with no changes
2. **Expected: pre-check failure — "Insufficient healthy nodes (2 < 3)"**
