# DISC QUEST

The first Godot 4 prototype for a portrait mobile sports puzzle game.

## Current step

The prototype now includes:

- A portrait rink with a polished 2.5D presentation.
- A player disc and Jack target.
- Touch or mouse drag-to-aim controls.
- Physics-based launch, friction, and rink boundary limits.
- Three throws per level with distance scoring.
- Five level configurations with different Jack positions.
- Reset and next-level controls.

The code stays deliberately small. Advanced disc types, spin, obstacles, AI,
multiplayer, and generated level systems are not part of this MVP.

## Run it in Godot

1. Open Godot 4.
2. Choose **Import**.
3. Select the `disc-quest/project.godot` file.
4. Press the Play button.

The project is set up for a 540 x 960 portrait viewport. On a desktop, the
window may appear as a narrow portrait game window. That is expected.

## Test the MVP

1. Touch and hold the blue disc near the bottom of the rink.
2. Drag backwards. The dotted guide shows the direction and power.
3. Release to launch the disc.
4. Wait for it to stop. The distance to the Jack is recorded automatically.
5. Repeat until all three throws are used.
6. Use **RESET** to replay the current level or **NEXT LEVEL** after a
   completed level.

On desktop, use the left mouse button in place of touch.