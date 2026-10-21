# DISC QUEST

The first Godot 4 prototype for a portrait mobile sports puzzle game.

## Current step

The prototype now includes:

- A real 3D lawn-bowls rink, 38 m long by 5.8 m wide, viewed in perspective from behind the mat.
- Mowed green, timber banks, ditch, center line, delivery mat, and a bullseye head.
- Clubhouse, trees, hedges, benches, and paths around the green.
- A player disc and Jack that sit on the green and scale with distance.
- Touch or mouse drag-to-aim controls.
- Physics-based launch, friction, bias curve, visible spin, and rink boundary limits.
- Three throws per level with distance scoring in metres.
- Five level configurations with different Jack positions on the head.
- Reset, bias, and next-level controls.

The current disc uses center, left, and right bias. Bias bends the shot more
as the disc slows, while the disc spins during flight. Obstacles, AI,
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
2. Drag backwards. The curved guide shows direction, power, and bias.
3. Release to launch the disc.
4. Tap **BIAS** to cycle between CENTER, LEFT, and RIGHT before a throw.
5. Wait for it to stop. The distance to the Jack is recorded automatically.
6. Repeat until all three throws are used.
7. Use **RESET** to replay the current level or **NEXT LEVEL** after a
   completed level.

On desktop, use the left mouse button in place of touch.