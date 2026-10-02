# Echoes of Complicity

A first-person psychological-horror narrative game for **Godot 4.3** (GDScript, Compatibility renderer).
You are a mid-level administrator at a humanitarian megacorp. Every decision feels reasonable. All paths converge.
No gore, no jump scares; the horror is moral recognition.

## Run
Open the folder in Godot 4.3+ and press F5. No external assets: the office, colleagues and skyline are built from primitives in code, and the muzak is synthesized.

## Controls
WASD move · Shift sprint · Mouse look · **E** interact · 1/2/3 pick an option · Esc step away from the terminal

## How it plays
- Walk to your terminal at the far end of the office (glowing amber, by the window). Each file arrives with a message from a pen pal in Kessara, then a case.
- Act I (6 files): approve loans, shipments, contracts. Each looks good; the fine print is in small grey type.
- Act II (5 files): reports arrive. Investigate, accept the talking points, or escalate. Every path ends in the same place.
- Act III: Authorization 77-K. Sign, refuse, or leak. Three endings, no good one.
- Talk to colleagues, read the posters, look out the window. The office lighting, posters, ticker and elevator music all sour as your dissonance rises.
- Pick a playstyle (Pragmatist / Idealist / Cynic): it changes the narrator's voice and how fast guilt accrues.
- **Replay:** the fine print you scrolled past is highlighted in red on the second run.

## Dev
- `scripts/story_data.gd` all content; `game_state.gd` rules; `ui.gd` interface; `main.gd` world, player, flow.
- Smoke test (plays the full game, saves screenshots to `$SHOT_DIR`):
  `xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy -- --autotest`
