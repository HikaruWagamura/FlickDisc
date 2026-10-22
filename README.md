# DISC QUEST

The first Godot 4 prototype for a portrait mobile sports puzzle game.

## Current step

The prototype now includes:

- A real 3D lawn-bowls rink, 68 m long by 11 m wide, viewed in perspective from behind the mat.
- Mowed green, timber banks, ditch, center line, delivery mat, and a bullseye head.
- Clubhouse, trees, hedges, benches, and paths around the green.
- A 68 m by 11 m green. Choose a short jack (14–28 m) or a long jack (44 m or more).
- Banks rebound by default. DITCH ON opens a narrow ditch on each side and at the far end. A bowl that crosses the line is dead. If the jack is knocked in, it is re-spotted on the centre line and one of the two spare dots on the back bank is used.
- Four small discs are lined up for each end. For each shot, choose narrow, medium, wide, or hook, and send it forehand or backhand.
- The aim dots show only the opening line, so the rest spot stays yours to judge.
- After the fourth bowl the view closes in on the head. Every bowl inside 2 m of the jack is a shot. Play a chosen number of ends, or first to 11 or 21.
- Every bowl stays on the green. Later bowls knock earlier bowls and the jack on every level.
- Touch or mouse drag-to-aim controls, with haptic pulses and synthesized hit, roll, and settle sounds.
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

## Native app

The phone build is still the native app. A Web preset exists only so the same
game can be played in a browser without installing an APK. iOS uses the same
project, exported from Godot on macOS.

Android (debug APK):

1. Install Godot 4.5 export templates (Editor → Manage Export Templates).
2. Install the Android SDK (platform 35, build-tools 35) and JDK 17 or 21.
3. In Editor Settings → Export → Android, set the Android SDK path, the Java
   SDK path, and a debug keystore (`androiddebugkey` / `android`).
4. Project → Install Android Build Template. That copies the Gradle project
   into `android/build` (generated, not committed).
5. Project → Export, choose the **Android** preset, and export
   `build/disc-quest.apk`.

The Android preset is `com.discquest.app`, portrait, immersive, arm64-v8a and
x86_64, APK (not AAB). On a device, drag with a finger. The desktop mouse path
stays separate so a touch is not launched twice.

A Linux preset exports `build/disc-quest.x86_64` for a desktop native check.
The Web preset exports `build/web/index.html` (no threads, so a normal browser
can open it). Serve that folder over HTTP and drag the disc with the mouse.

## Test the MVP

1. Choose REBOUND or DITCH ON. Pull down on the dial at the right of the green to place the jack wherever you want it. A jack in the ditch is thrown again.
2. The same dial sends each disc. Pull down for pace and sideways for the line.
3. The guide shows the opening of the delivery and the start of the draw.
4. Release. With banks, a bowl rebounds. With ditches, a bowl that crosses the side or the far end is dead. A jack knocked into the ditch is replaced from the spare dots.
5. Use the arrows for FOREHAND and BACKHAND. The arrows point the way that bowl will bend. Pick one bias for the shot you are about to play.
6. Wait for it to stop. A bowl in the ditch does not count. The closest bowl still on the green is the score.
7. Repeat until all four discs are used. A firm pull reaches the far end. A harder pull can fire off the back when the ditch is on.
8. Use **RESET** to replay the current level or **NEXT LEVEL** after a
   completed level.

On desktop, use the left mouse button in place of touch.