# Metaphone LAN Synchronisation — Technical Reference

## Overview

Three (or more) Quest 3 headsets play a shared music sequencer in lock-step over a local WiFi network. All headsets fire their MIDI steps at the same wall-clock instant. The system achieves this with two mechanisms working together:

1. **NTP-style RTT clock offset measurement** — each device learns how far its `Time.get_ticks_usec()` clock is ahead of or behind every other device.
2. **Shared epoch firing** — a single absolute timestamp defines when tick 0 fires. Every device independently computes when each subsequent tick is due using pure arithmetic. There is no accumulated drift.

The architecture is inspired by [Ableton Link](https://www.ableton.com/en/link/).

---

## Why Previous Approaches Failed

### Approach 1 — Send STEP on every tick
The conductor sent a UDP message on each timer tick. Slaves fired their notes on receipt. Result: every note was delayed by exactly the network round-trip time (~5–20 ms). Audibly flammy.

### Approach 2 — Independent timers + SYNC corrections
Each device ran a Godot `$Timer`. The conductor periodically sent its tick count; slaves snapped their position if they drifted. Two problems:

- **Godot Timer drift.** `$Timer` fires via the `_process` delta accumulation loop. At 90 Hz, each frame is ~11 ms. A timer set to 125 ms (120 BPM sixteenth note) fires 0–11 ms late each tick, randomly. Two headsets accumulate different random errors and diverge over bars.
- **SYNC made things worse.** SYNC used `Time.get_unix_time_from_system()` to compute tick position. Quest 3 Android devices are not guaranteed to have NTP-synchronised clocks — they can differ by 50–500 ms. SYNC was snapping slaves to a wrong position every 16 steps, *causing* the drift it was meant to fix.

### Approach 3 — Shared UTC epoch (broken)
The conductor computed a shared epoch using `int(Time.get_unix_time_from_system() * 1_000_000)`. This is the right idea but uses the wrong clock. `get_unix_time_from_system()` is only as accurate as NTP. On a local router without guaranteed internet access, two Quest 3s can be hundreds of milliseconds apart on this clock.

---

## The Correct Architecture

### Key Insight

`Time.get_ticks_usec()` is a **monotonic clock** that counts microseconds since the process started. It is stable and drift-free on each device. But its *origin* (zero point) is different on every device — one headset might read 12,345,678 µs while another reads 7,890,123 µs at the exact same wall-clock instant.

If we know the **offset** between two clocks, we can convert timestamps between them. The offset is constant (both clocks tick at the same crystal rate):

```
offset(A→B) = B_ticks - A_ticks   [measured at the same wall-clock instant]
```

We measure this offset using a **ping/pong round-trip** (simplified NTP).

---

## Phase 1 — Peer Discovery

Every device broadcasts a UDP `HELLO` message every 2 seconds to `255.255.255.255:4242`. When a new peer is heard, it is added to the peers table and **immediately pinged** to establish clock offset.

```
NetworkManager._process()  every 2s:
    UDP broadcast → "HELLO:<my_id>"

On receiving HELLO from unknown peer:
    peers[sender_id] = {ip, age=0}
    _ping(sender_id)       ← triggers clock sync immediately
```

---

## Phase 2 — Clock Offset Measurement (RTT Ping/Pong)

This runs continuously: once on peer discovery, then every 2 seconds.

```
Device A (pinger)                    Device B (responder)
      |                                    |
  t1 = get_ticks_usec()                   |
      |── PING:A_id:t1 ──────────────────>|
      |                               t2 = get_ticks_usec()
      |<── PONG:B_id:t1:t2 ─────────────|
  t3 = get_ticks_usec()                   |
      |                                    |
  RTT     = t3 - t1
  offset  = t2 - (t1 + RTT/2)
```

**Why this works:**

At the midpoint of the round trip, device A's clock reads `t1 + RTT/2`. Device B's clock read `t2` at approximately the same wall-clock instant. Therefore:

```
offset = B_ticks - A_ticks = t2 - (t1 + RTT/2)
```

**Error bound:** The assumption of symmetric latency is imperfect. The error equals half the jitter in one-way delay, typically **< 2 ms on LAN WiFi**. At 120 BPM (125 ms per sixteenth note), this is < 1.6% of a step — inaudible.

### Code (NetworkManager)

```gdscript
func _ping(peer_id: String) -> void:
    var t := Time.get_ticks_usec()
    _pending_pings[peer_id] = t
    _udp.set_dest_address(peers[peer_id].ip, PORT)
    _udp.put_packet(("PING:%s:%d" % [my_id, t]).to_utf8_buffer())

# On receiving PING — respond immediately (low latency matters here)
"PING":
    var their_t1: int = parts[2].to_int()
    var my_t2: int = Time.get_ticks_usec()
    _udp.put_packet(("PONG:%s:%d:%d" % [my_id, their_t1, my_t2]).to_utf8_buffer())

# On receiving PONG — compute and store offset
"PONG":
    var our_t1: int  = parts[2].to_int()
    var sender_t2: int = parts[3].to_int()
    var now: int     = Time.get_ticks_usec()
    var rtt: int     = now - our_t1
    var offset: int  = sender_t2 - (our_t1 + rtt / 2)
    clock_offsets[sender_id] = offset
    # offset = sender_ticks - our_ticks
```

`clock_offsets[peer_id]` is updated every 2 seconds for the lifetime of the session.

---

## Phase 3 — Playback Start (Shared Epoch)

When a user presses the START button, that device becomes the **conductor**. All other devices are **slaves**.

### The Epoch

The epoch is a single `int` — a value of `Time.get_ticks_usec()` **in the conductor's local clock** at which tick 0 fires. It is set 400 ms in the future to give all peers time to receive the START message before playback begins.

```
Conductor:
    _epoch_local = Time.get_ticks_usec() + 400_000
    send START to all peers: (tick_duration_usec, _epoch_local)
```

### Epoch Conversion on Slaves

The slave cannot use the conductor's epoch directly because the two clocks have different origins. The slave converts it using the measured offset:

```
offset = conductor_ticks - slave_ticks
slave_epoch = conductor_epoch - offset
```

**Proof of correctness:**

At the moment tick 0 should fire (wall-clock time T):
- Conductor's clock reads: `conductor_epoch`
- Slave's clock reads: `conductor_epoch - offset = conductor_epoch - (conductor_ticks - slave_ticks) = slave_ticks`

Both clocks reach their respective epoch values at the same wall-clock instant T. ✓

```gdscript
# instruments.gd
func _to_local_epoch(conductor_epoch: int) -> int:
    var offset: int = _net.clock_offsets.get(conductor_id, 0)
    return conductor_epoch - offset

func _on_remote_start(peer_id: String, tick_duration_usec: int, conductor_epoch: int) -> void:
    conductor_id = peer_id
    _tick_duration_usec = tick_duration_usec
    _epoch_local = _to_local_epoch(conductor_epoch)
    var now: int = Time.get_ticks_usec()
    _tick = max(0, (now - _epoch_local) / _tick_duration_usec)
    for sequencer in sequencers:
        sequencer.step_index = _tick % sequencer.steps
```

---

## Phase 4 — Tick Firing (Wall-Clock Loop)

Every device fires ticks from `_process()` — **not** from a `$Timer`. This eliminates Godot Timer drift entirely.

Tick N is due when:
```
Time.get_ticks_usec() >= _epoch_local + N * _tick_duration_usec
```

Since `_epoch_local` and `_tick_duration_usec` are the same on all devices (after offset conversion), all devices evaluate this condition true at the same wall-clock instant.

```gdscript
func _process(_delta: float) -> void:
    if is_playing:
        var now: int = Time.get_ticks_usec()
        while now >= _epoch_local + _tick * _tick_duration_usec:
            _do_step()
            _tick += 1
            if is_conductor and _tick % SYNC_INTERVAL == 0:
                _net.send_sync_to_all(_tick_duration_usec, _epoch_local)
```

The `while` loop (not `if`) catches up correctly if a frame runs long — it fires all missed ticks in order, then waits for the next due time. No ticks are ever skipped or double-counted.

---

## Timeline: Full Session

```
t=0s    Headsets boot, HELLO broadcasts begin every 2s
        ┌─────────┐         ┌─────────┐         ┌─────────┐
        │Quest A  │         │Quest B  │         │Quest C  │
        └────┬────┘         └────┬────┘         └────┬────┘
             │                   │                   │
t=0.1s       │──── HELLO ───────>│                   │
             │<─── HELLO ────────│                   │
             │──── PING(t1) ────>│                   │
             │<─── PONG(t1,t2) ──│  offset A→B known │
             │                   │                   │
             │──────────────── HELLO ───────────────>│
             │<─────────────── HELLO ────────────────│
             │──────────────── PING(t3) ────────────>│
             │<─────────────── PONG(t3,t4) ──────────│  offset A→C known
             │                   │                   │
             │                   │──── HELLO ───────>│
             │                   │<─── HELLO ────────│
             │                   │──── PING ─────────>   offset B→C known
             │                   │<─── PONG ──────────
             │                   │                   │
t=5s   [User presses START on A]
             │                   │                   │
             │  epoch = now+400ms                    │
             │──── START(dur, epoch) ───────────────>│
             │──── START(dur, epoch) ─────────────>  │
             │                   │                   │
             │          slave_epoch_B = epoch - offset(A→B)
             │                             slave_epoch_C = epoch - offset(A→C)
             │                   │                   │
t=5.4s  TICK 0 fires on all three devices simultaneously
             │                   │                   │
            🔊                  🔊                  🔊
```

---

## BPM Changes at Runtime

When the conductor moves the tempo slider, the BPM change is debounced (150 ms) to avoid a flood of messages during dragging. On commit:

1. `_tick_duration_usec` is updated to the new value.
2. The epoch is **reanchored**: adjusted so that tick `_tick` fires at the current moment. This preserves the playback position without a glitch.
3. The new `(bpm, _tick, new_epoch)` is broadcast to all slaves.

```
New epoch such that tick N fires "now":
    _epoch_local = now - _tick * new_tick_duration_usec

Broadcast: BPM:id:bpm:tick:epoch
```

Slaves receive `BPM`, update `_tick_duration_usec`, convert the epoch via `_to_local_epoch()`, and set `_tick`. Because the epoch encodes position as well as rate, slaves atomically resync both tempo and step position in one message.

```gdscript
func _on_local_bpm_changed(bpm: int) -> void:
    _tick_duration_usec = _bpm_to_usec(bpm)
    var now: int = Time.get_ticks_usec()
    _epoch_local = now - _tick * _tick_duration_usec
    _net.send_bpm_to_all(bpm, _tick, _epoch_local)

func _on_bpm_received(bpm: int, tick: int, conductor_epoch: int) -> void:
    _tick_duration_usec = _bpm_to_usec(bpm)
    _epoch_local = _to_local_epoch(conductor_epoch)
    _tick = tick
```

---

## SYNC — Safety Net

Every 32 ticks the conductor rebroadcasts `(tick_duration_usec, epoch)`. Slaves update their local epoch but **do not recompute `_tick`**. This handles:

- A slave that missed the START message
- Slow clock offset measurement drift over a long session

Because `_tick` is not reset on SYNC, there are no step-position jumps during normal operation.

---

## Stop / Resume

When stop is pressed, `is_playing = false` and the `_process` loop stops firing ticks. `_tick` retains its current value.

On the next START, the conductor sets:
```
_epoch_local = now + LOOKAHEAD_USEC - _tick * _tick_duration_usec
```

This anchors the epoch so that tick `_tick` fires 400 ms from now — playback resumes from exactly where it stopped. Slaves derive their own `_epoch_local` the same way via offset conversion, and set `step_index = _tick % steps`.

---

## Message Reference

All messages are UTF-8 strings over UDP port 4242. Fields are colon-separated.

| Message | Format | Direction | Purpose |
|---------|--------|-----------|---------|
| `HELLO` | `HELLO:id` | Broadcast | Peer discovery / heartbeat |
| `PING` | `PING:id:t1` | Unicast | Clock offset measurement |
| `PONG` | `PONG:id:t1:t2` | Unicast | Clock offset reply |
| `START` | `START:id:dur:epoch` | Unicast to all | Begin playback |
| `STOP` | `STOP:id` | Unicast to all | Halt playback |
| `SYNC` | `SYNC:id:dur:epoch` | Unicast to all | Safety-net epoch rebroadcast |
| `BPM` | `BPM:id:bpm:tick:epoch` | Unicast to all | Tempo change |

- `dur` — tick duration in microseconds (`60_000_000 / bpm / 4`)
- `epoch` — `Time.get_ticks_usec()` value of tick 0 in the **conductor's** local clock
- `tick` — current tick count at time of message

---

## Error Budget at 120 BPM

| Source | Magnitude | Notes |
|--------|-----------|-------|
| RTT asymmetry (WiFi) | < 2 ms | Half the one-way jitter |
| Frame overshoot (90 Hz) | < 11 ms | `_process` fires slightly late |
| Accumulated drift | **0** | Epoch-based: no accumulation |
| **Total worst case** | **~13 ms** | 10% of a 125 ms step |

In practice, frame overshoot is the dominant term. A dropped frame on one headset (e.g., during heavy rendering) can cause a single note to fire ~16 ms late. This is the hard limit of `_process`-based scheduling in a game engine without real-time audio thread access.

---

## Files

| File | Role |
|------|------|
| `network_manager.gd` | UDP transport, peer discovery, PING/PONG, clock offsets |
| `instruments.gd` | Conductor/slave logic, epoch management, tick firing |
| `tempo.gd` | BPM slider with 150 ms debounce |
| `debug_log.gd` | Autoload singleton — logs offset/RTT measurements to a 3D Label |
