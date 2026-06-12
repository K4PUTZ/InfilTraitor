# INFILTRAITOR — Audio Pipeline & Roadmap

> **Sound design, music, and audio feedback systems.**

---

## Audio Categories

---

## 1. Ambient & Environmental

### Facility Ambience (Low Priority)

| Sound | Status | Duration | Priority | ETA |
|-------|--------|----------|----------|-----|
| Facility hum (HVAC) | Not started | Loop | Low | M6-02 |
| Electrical hum | Not started | Loop | Low | M6-02 |
| Distant machinery | Not started | Loop | Low | M6-02 |
| Fluorescent buzz | Not started | Loop | Low | M6-02 |

---

## 2. Footsteps & Movement (High Priority)

### Guard Footsteps

| Sound | Surface | Status | ETA | Notes |
|-------|---------|--------|-----|-------|
| **Guard footsteps (heavy)** | Metal grate | Not started | This sprint | Booted, impacts |
| **Guard footsteps (light)** | Tile floor | Not started | This sprint | Softer, less menacing |
| **Guard movement shuffle** | Carpet | Not started | Next sprint | Barely audible |
| **Equipment jingle** | Gear | Not started | Next sprint | Keys, gear clink |

### Agent Footsteps

| Sound | Surface | Status | ETA | Notes |
|-------|---------|--------|-----|-------|
| **Agent footsteps (soft)** | Tile floor | Not started | This sprint | Quiet, stealthy |
| **Agent footsteps (careful)** | Carpet | Not started | This sprint | Barely audible |
| **Running footsteps** | Any surface | Not started | Combat phase | Loud, panicked |

---

## 3. Alerts & Communication (High Priority)

### Immediate Reactions

| Sound | Status | ETA | Context | Notes |
|--------|--------|-----|---------|-------|
| **Detection meter tick** | Not started | This sprint | Every tick | Tension builder |
| **Alert complete (CHASE)** | Not started | This sprint | Full detection | Sharp, urgent |
| **Whistle (guard alert)** | Not started | This sprint | Nearby detection | 3-tile radius propagation |
| **Radio burst** | Not started | Next sprint | Global alert | Squelch + voice pattern |

### Escalation Sounds

| Sound | Status | ETA | Condition |
|-------|--------|-----|-----------|
| **Suspicious mode** | Not started | Next sprint | Detection 0.3+ |
| **Alert mode** | Not started | Next sprint | Detection 0.6+ |
| **Chase activation** | Not started | This sprint | Detection 1.0 |
| **Search activation** | Not started | Next sprint | Lost target |

---

## 4. Gadgets & Interaction (Medium Priority)

### Gadget Usage

| Sound | Gadget | Status | ETA |
|-------|--------|--------|-----|
| **Activation beep** | Smoke Bomb | Not started | This sprint |
| **Hissing release** | Smoke Bomb | Not started | This sprint |
| **EMP crackle** | EMP Device | Not started | Next sprint |
| **Beep sequence** | EMP Device | Not started | Next sprint |
| **Decoy chirp** | Decoy | Not started | Combat phase |
| **Flashbang pop** | Flashbang | Not started | Combat phase |

### Interaction Sounds

| Sound | Interaction | Status | ETA |
|-------|------------|--------|-----|
| **Door unlock click** | Door unlock | Not started | M3-02 |
| **Door open creak** | Door opening | Not started | M3-02 |
| **Terminal boot** | Hacking | Not started | M3-02 |
| **Keypad beep** | Hacking | Not started | M3-02 |

---

## 5. UI & Feedback (Low Priority)

| Sound | Context | Status | ETA |
|-------|---------|--------|-----|
| **Menu click** | UI button | Not started | M6-01 |
| **Selection beep** | Selection | Not started | M6-01 |
| **Error buzz** | Invalid action | Not started | M6-01 |
| **Notification ding** | Alert to player | Not started | M6-01 |

---

## 6. Adaptive Music (Very Low Priority)

### Music States

| State | Track Style | Status | ETA | Notes |
|-------|------------|--------|-----|-------|
| **Patrol (calm)** | Ambient, minimal | Not started | M6-02 | Relaxed, atmospheric |
| **Suspicious (tense)** | Rising tension | Not started | M6-02 | Building dread |
| **Alert (urgent)** | Fast, percussive | Not started | M6-02 | Action tempo |
| **Chase (intense)** | High energy | Not started | Combat phase | Frantic, urgent |
| **Safe zone** | Resolved, calm | Not started | M6-02 | Relief |

### Music Implementation
- **State-based transitions** (not cross-fade, abrupt)
- **Mixing levels:** Music 50%, SFX 100%, Ambience 30%
- **Silence periods:** Allow tension buildup

---

## 7. Radio Chatter (Low Priority)

### Communication Patterns

| Pattern | Status | ETA | Purpose |
|---------|--------|-----|---------|
| **Alert broadcast** | Not started | M6-02 | "All units, alert status!" |
| **Guard chatter** | Not started | M6-02 | Ambient faction comms |
| **Enemy callout** | Not started | M6-02 | "Intruder in sector 3!" |
| **Static noise** | Not started | M6-02 | Background radio hum |

---

## Audio Design Principles

1. **Clarity First** — SFX must be clear and unambiguous
2. **Feedback Immediate** — Player actions get instant audio response
3. **Spatialization** — Use panning/3D audio for direction cues
4. **Layering** — Build tension through layered ambience
5. **Minimize** — Avoid audio clutter (reduce SFX count during intense moments)

---

## Audio Asset Pipeline

### 1. Sourcing
- Internal recording (footsteps, impacts)
- External libraries (freesound.org, zapsplat)
- Contract professional sound designer (TBD)

### 2. Processing
- Normalize levels (-6 dB average)
- EQ adjustment (remove rumble, enhance presence)
- Compression/limiting
- Looping setup (if applicable)

### 3. Implementation
- Import to Godot as .ogg (opus codec)
- Set gain levels (-20 dB to +10 dB range)
- Configure 3D audio (falloff, pan)
- Test mixing levels

### 4. Integration
- Hook to gameplay events
- Test lip-sync (if applicable)
- Balance with other audio
- Performance pass

---

## Audio Priority Schedule

### This Sprint (M2-14)
- Footstep SFX (guard + agent)
- Detection meter ticks
- Alert whistle
- Smoke bomb hiss
- Integration testing

### Next Sprint (M2-15)
- Radio sounds
- Additional reaction sounds
- Environmental ambience (optional)
- Music framework setup

### Polish Phase (M6-02)
- Adaptive music implementation
- Audio mixing & mastering
- Final balance pass
- Accessibility audio options

---

## Audio Localization (Future)

| Language | Status | ETA |
|----------|--------|-----|
| English | — | Launch |
| Portuguese (BR) | Planned | Post-launch |
| Spanish | Planned | Post-launch |
| French | Planned | Post-launch |

---

## Audio Accessibility

| Feature | Status | ETA |
|---------|--------|-----|
| **Subtitles** | Planned | M6-04 |
| **Visual feedback** | Planned | M6-04 |
| **Volume control** | Planned | M6-01 |
| **Sound effect toggle** | Planned | M6-04 |

---

## Metrics

| Metric | Target | Status |
|--------|--------|--------|
| **SFX count** | 20–30 | 0 |
| **Ambient tracks** | 3–5 | 0 |
| **Music tracks** | 5–8 | 0 |
| **Total audio assets** | 30–40 | TBD |
| **Audio file size** | <50 MB (OGG compressed) | TBD |

---

**Last Updated:** 2026-06-11  
**Maintained By:** Audio Director  
**Status:** Planning Phase 🟡
