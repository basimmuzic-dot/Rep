# Echoes of Complicity

A Godot 4.3 narrative game about complicity, corporate harm, and the mechanisms of good intentions.

## Overview

You are a mid-level administrator at Meridian Concord, a humanitarian megacorp operating in the fictional region of Kessara. Over four acts, you approve humanitarian projects—loans, healthcare shipments, development contracts, educational programs—while gradually discovering that the systems you serve are mechanisms of extraction and control.

The game explores how good intentions can be weaponized, how complexity enables harm, and how the most insidious systems profit from the desire to help.

## Gameplay

- **First-person exploration**: Walk through a corporate office environment using WASD keys.
- **Mouse look**: Move the mouse to look around. Mouse is captured during gameplay.
- **Interact**: Press E near the desk terminal to open case files.
- **Case decisions**: Read each case and choose to approve, review, investigate, or decline. Each choice carries moral weight and affects the game's narrative and aesthetics.
- **Playstyle selection**: At game start, choose a philosophical approach (Pragmatist, Idealist, or Cynic) that shapes the narrator's voice and dissonance accumulation.

## Controls

| Control | Action |
|---------|--------|
| W       | Move forward |
| A       | Move left |
| S       | Move backward |
| D       | Move right |
| Mouse   | Look around |
| E       | Interact with terminal |

## How to Run

### Requirements
- Godot 4.3+ (headless or full editor)
- GDScript 4.0 syntax support

### Opening in Godot Editor
1. Download Godot 4.3 from [godotengine.org](https://godotengine.org)
2. Open the project root directory in the Godot editor
3. Press F5 or click Play to run the game

### Running from Command Line (Headless)
```bash
godot --headless --path . --run
```

### Checking for Syntax Errors
```bash
godot --headless --path . --quit
```

## Design Notes

### Narrative Structure

**Act I: Approval** (6 cases)
You approve humanitarian projects. Each approval feels good. The impact ticker celebrates your help. But each project contains hidden mechanisms of harm—extraction clauses in fine print, dependency creation, elite enrichment, propaganda education, locked supply chains, predatory lending.

**Act II: Fragmentation** (5 cases)
Reports surface of problems in villages you funded. For each, you can investigate (raising dissonance and revealing truth) or accept corporate talking points (rationalizing and ignoring). The three pen pals' messages darken with each case, reflecting the growing crisis.

**Act III: Final Choice** (1 case)
You're presented with Project Meridian: the plan to formalize corporate control. Three choices:
- **Sign**: Accept promotion, tell yourself you did good work
- **Refuse**: Become a whistleblower, blamed and exiled
- **Leak**: Leak documents yourself, get captured, imprisoned

**Act IV: Epilogue**
Each choice leads to a distinct ending:
- **Sign**: Promoted, celebrated, photographs on your desk, never looking closely at the results
- **Refuse**: Blamed, exiled, unable to speak due to NDAs, watching documentaries helplessly
- **Leak**: Imprisoned, freed in a prisoner exchange, watching a failed state you tried to stop, your leak didn't save the region

### Mechanics

**Dissonance System**
A meter (0-100) tracking cognitive dissonance. As it rises:
- Office lighting shifts from warm (orange/yellow) to cold (blue)
- Wall posters mutate: "IMPACT" becomes "EXTRACTION", "PARTNERS" becomes "DEPENDENTS"
- Narrator voice shifts from rationalization to self-awareness
- Each choice contributes differently based on investigation vs. rationalization

**Playstyles**
Three philosophical approaches that change the narrator's voice and slightly adjust dissonance accumulation:
- **Pragmatist**: "Results matter. Good intentions alone change nothing." Early narrator justifies by outcomes.
- **Idealist**: "Humanity first. Systems can be fixed from within." Early narrator believes in internal reform.
- **Cynic**: "Everything is extraction. Play honestly." Early narrator is self-aware about extraction but underestimates scale.

All three converge in Act II toward the same realization.

**Pen Pal System**
Three characters send messages between cases:
- **Amara**: A schoolteacher; her messages show curriculum concerns, family displacement, job offers
- **Dr. Teo**: A clinic nurse; discovers the medications are expired trial drugs, goes into hiding
- **Jun**: A teenager; receives seeds that lock his family into yearly purchases, loses the farm, becomes factory worker

Their messages provide emotional grounding to the systemic harms. On replay, you can see how their fates were sealed by choices you made.

### Technical Details

**Built from Primitives**
- BoxMesh for floor, walls, ceiling, panels, desks, monitors, terminal
- CSGBox3D concepts implemented via MeshInstance3D + CollisionShape3D
- Label3D for wall posters
- StandardMaterial3D for all surface coloring and lighting responses
- OmniLight3D for ambient warm-to-cold lighting shifts
- WorldEnvironment for scene background

**No External Assets**
- All meshes are procedurally instantiated
- All materials are dynamically created and assigned
- No image files, audio files, or 3D models

**Procedural Audio (Optional)**
The game includes support for procedural audio via AudioStreamGenerator with a cheerful major-chord arpeggio that detunes and shifts toward minor as dissonance rises. This is wrapped in safe try/catch to not break the game if synthesis fails.

**UI System**
- CanvasLayer-based UI built entirely in code
- Case file panel with title, body (RichTextLabel for text formatting), and choice buttons
- Monologue line at bottom (narrator voice, context-sensitive)
- Impact ticker (top-right, shows current dissonance and lives helped)
- Playstyle selection screen at game start
- Ending screens with "Play Again" button

### Replay Mode

On subsequent playthroughs:
- Set `GameState.replay = true` to unlock additional annotation hints
- Earlier case files show `[you missed this]` notes highlighting hidden clauses
- Narrator references the previous playthrough
- This mode is not fully implemented in this version but the flag is in place for future enhancement

## Themes

**Complicity as a System**
The game argues that harm doesn't require malice—only good intentions, institutional complexity, and cognitive dissonance management. Every choice feels good locally while enabling harm globally.

**Good Intentions as Mechanism**
The humanitarian narrative becomes the machinery of control. Meridian Concord is not a villain; it's a system that profits from helping. This is more dangerous than simple greed.

**Moral Recognition vs. Change**
By the time you understand the harm, you're already complicit. No choice is good. The game offers no redemption arc—only recognition of the mechanism.

## Files

- `project.godot` — Godot engine configuration
- `scenes/main.tscn` — Main scene (minimal, script-built environment)
- `scripts/main.gd` — Core game controller, environment builder, player setup, UI
- `scripts/game_state.gd` — Autoload singleton tracking progression, dissonance, pen pals
- `scripts/story_data.gd` — Pure data: all narrative content, choices, endings
- `.gitignore` — Git ignore file (godot runtime, imports)
- `README.md` — This file

## Credits

Designed and implemented as a narrative game about systemic harm, corporate complicity, and the way good intentions enable extraction.

Built with Godot 4.3 and GDScript 4.

## License

All content proprietary / personal project.
