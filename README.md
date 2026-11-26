# FlickDisc

Portrait club for two tables. The game opens on the FlickDisc splash and home. **Play** leads to Classic 1v1. **FlickDisc** is the round crokinole board. **Flick Bowls** is the long green and the jack. Practice, challenges, friends, rankings, profile, customise, shop, and settings live on the same menu.

A finished match writes the win or loss onto this device. Challenges clear when the shot lands: the 20, a 15, or a bowl inside a metre of the jack. Online rows are on the Classic screen; this build plays that setup on the same device until a club server is connected.

## Tables

### FlickDisc

The paid crokinole club board, pins, and discs. Touch the disc and drag the dots to aim, then tap to lock. Pull back and release on the line. Eight discs each. 20 is the centre hole, and that disc is lifted onto the score. 15, 10 and 5 need the disc clear of that line. A disc on the line scores the lower ring. If an opponent is on the board you must hit one; if the board is empty you must finish in the 15. The ditch is nothing. Only the difference is added. First to the race wins.

### Flick Bowls

The long green. Paid lawn-bowl meshes, red and blue. Touch the jack and drag the dots to aim, then tap to lock. Pull back and release on the line. Red bowls four, then blue bowls four. The side closest to the jack scores every bowl nearer than the other side. Play one end, four ends, first to 10, or first to 21. Chase cam follows the bowl. Banks rebound unless the ditch is open. Choose narrow, medium, wide, or hook, and send it forehand or backhand.

## Run it in Godot

1. Open Godot 4.3.
2. Choose **Import**.
3. Select the `project.godot` file.
4. Press the Play button.

The project is set up for a 540 x 960 portrait viewport. On a desktop, the window may appear as a narrow portrait game window. That is expected.

## Native app

The phone build is the native app. A Web preset exists so the same game can be played in a browser without installing an APK.

Android:

1. Install Godot 4.3 export templates.
2. Install the Android SDK and JDK.
3. Project → Export, choose the **Android APK** preset, and export `dist/FlickDisc-1.4.0.apk`.

The Android package is portrait, immersive, arm64-v8a. On a device, drag with a finger.

A Linux preset exports `build/FlickDisc.x86_64` for a desktop native check. The Web preset exports `web/index.html` (no threads, so a normal browser can open it). Serve that folder over HTTP.

## Test

1. Open FlickDisc, skip the splash, and pick **Play**.
2. Choose the round board for FlickDisc, or the long green for Flick Bowls.
3. On FlickDisc, pull a disc and release on the green. Pegs and discs are live.
4. On Flick Bowls, place the jack, pick a bias, then pull the bowl. Chase cam follows. DITCH ON opens the ditch.
