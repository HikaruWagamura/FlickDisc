# DISC QUEST

Portrait crokinole game. The table is a 3D board viewed from the player's seat.

## Current step

The Flick Disc artwork is printed on the round board. From the overview you also see the long club rink and its jack behind the table. Eight pegs stand on the 15-point circle, and buttons stay where they stop.

- Wooden surface, recessed ditch, outer rail, and a center 20-hole.
- Scoring rings: 20 in the hole, 15 inside the pegs, 10, then 5 on the outer wood. The ditch scores nothing.
- Eight pegs. Discs bounce off the pegs, off each other, and off the rail.
- Eight player discs per round. Each one stays on the table, so later shots can hit it.
- Opponent discs sit on the far side. Knocking them around is part of the shot.
- Center, left, and right bias. The guide stops at the first peg or disc.
- Five layouts. The score is the total of your discs when the round ends.

## Run it in Godot

1. Open Godot 4.
2. Choose **Import**.
3. Select the `project.godot` file.
4. Press the Play button.

The project uses a 540 x 960 portrait viewport. On a desktop the window is a narrow portrait window.

## How to play

1. Touch the rose disc at the near side. A ring marks it while it is waiting.
2. Drag backward, toward yourself. The guide shows direction, power, and bias, and it stops when a peg or disc is in the way.
3. Release to flick. The disc slides the opposite way and caroms off pegs and other discs.
4. A disc that slows down in the 20-hole drops in for 20 points.
5. Tap **BIAS** to cycle CENTER, LEFT, and RIGHT before a shot.
6. After all eight discs, **RESET** replays the layout and **NEXT LEVEL** loads the next one.

On desktop, use the left mouse button in place of touch. Aiming is on the table plane, so a drag toward the bottom of the screen flicks the disc toward the far pegs.
