# DISC QUEST

Portrait sports game. The main table is a 3D crokinole board viewed from the player's seat.

## Current step

The playable view is a perspective camera over a round wooden board:

- Raised rail, pink rim, scoring rings, and a center 20-hole.
- One puck and a gold Jack. Drag backward from the puck and release to flick.
- The shot slides on the table, slows with friction, and rebounds off the rail.
- Center, left, and right bias. The guide shows the curve before you release.
- Three throws per level. Score comes from how close the puck stops to the Jack.
- Five levels, with the Jack in a different spot on the far half of the board.

## Run it in Godot

1. Open Godot 4.
2. Choose **Import**.
3. Select the `project.godot` file.
4. Press the Play button.

The project uses a 540 x 960 portrait viewport. On a desktop the window is a narrow portrait window.

## How to play

1. Touch the pink puck at the near end of the table. A ring marks it while it is waiting.
2. Drag backward, toward yourself. The guide shows direction, power, and bias.
3. Release to flick. The puck slides in the direction opposite your drag.
4. Tap **BIAS** to cycle CENTER, LEFT, and RIGHT before a throw.
5. When the puck stops, the distance to the Jack is recorded and the puck returns for the next throw.
6. Use **RESET** to replay the level, or **NEXT LEVEL** after the three throws.

On desktop, use the left mouse button in place of touch. Aiming is on the table plane, so a drag toward the bottom of the screen flicks the puck toward the far rail.
