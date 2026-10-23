# Control

Control is a macOS menu-bar utility that opens a radial application switcher when you hold the **Control** key. Move the pointer toward an application and release **Control** to activate it.

Control is an accessory app: it does not appear in the Dock or in the normal Command-Tab application switcher.

## Requirements

- macOS 13 or later
- Accessibility permission
- A Mac with a keyboard and pointer
- Xcode and Swift 6.0 only if building from source

## Install the release app

1. Download or obtain `Control.app`.
2. Drag `Control.app` into the `/Applications` folder.
3. Open `Control.app` once.
4. When macOS asks for permission, open:

   **System Settings → Privacy & Security → Accessibility**

5. Enable **Control**.
6. Quit and reopen Control if macOS asks you to relaunch it.

After it starts, Control appears as an icon in the menu bar.

## Launch at Login

Control registers itself as a macOS login item the first time it runs. If macOS requires approval, open:

**System Settings → General → Login Items**

Enable Control under the applications allowed to launch at login.

The menu-bar menu includes **Launch at Login**. Its checkmark shows whether the setting is enabled. Select it to turn automatic launch on or off.

## Using the application wheel

1. Hold the **Control** key for approximately 100 milliseconds.
2. The radial wheel appears around the pointer.
3. Move the pointer toward the application you want.
4. Release **Control** to switch to that application.

The wheel displays application icons only. It does not display application names or a full-screen dark overlay.

Pressing another key while the wheel is visible cancels the selection.

## Using Control in Mission Control

Control can display the wheel while Mission Control is visible.

1. Enter Mission Control, for example with **Control + Up Arrow**.
2. Hold **Control**.
3. Move the pointer over the application you want.
4. Release **Control**.

Control dismisses Mission Control and attempts to activate the selected application.

## Menu-bar controls

Click the Control icon in the menu bar to access:

- **About Control**
- **Launch at Login**
- **Quit**

Control remains active until **Quit** is selected.

## Build from source

The release branch is `main`. Build release apps from `main`, not directly from `control-dev`.

```bash
git clone https://github.com/ruth411/Control.git
cd Control
git switch main
git pull --ff-only origin main
```

Build the Swift package:

```bash
swift build -c release
```

Create the application bundle:

```bash
chmod +x bundle.sh
./bundle.sh
```

The resulting application is:

```
build/Control.app
```

Install it by dragging `build/Control.app` into `/Applications`, then open it once and grant Accessibility permission.

## Build and run in Xcode

1. Open the repository root in Xcode.
2. Select the **Control** scheme.
3. Build and run with **Command-R**.
4. Grant Accessibility permission when prompted.

Running from Xcode is useful for development. The installed release application should be built from the `main` branch.

## Run tests

From the repository root:

```bash
swift test
```

The test suite checks bundle metadata and the radial wheel presentation behavior.

## Development branches

Use `control-dev` for development work. Merge completed changes into `main` before creating a release app.

```bash
git switch control-dev
# make and test changes

git switch main
git pull --ff-only origin main
git merge --no-ff control-dev
git push origin main
```

Only build the release `Control.app` after switching to `main`.

## Troubleshooting

### The wheel does not appear

- Confirm Control is running; its icon should be visible in the menu bar.
- Confirm Control is enabled under **System Settings → Privacy & Security → Accessibility**.
- Quit and reopen Control after changing the permission.
- Hold Control long enough for the approximately 100 ms hold threshold.

### The wheel appears but does not switch applications

- Move the pointer clearly into an application segment before releasing Control.
- Avoid releasing inside the center dead zone.
- When using Mission Control, release only after hovering over the intended application.
- Confirm the selected application is still open.

### Control is not visible after restarting the Mac

Open **System Settings → General → Login Items** and make sure Control is enabled. You can also open Control manually from `/Applications`.

### macOS blocks the app

If the app is not notarized, macOS may show a security warning. In Finder, Control-click `Control.app`, choose **Open**, and confirm the prompt. Only do this for a build you trust.

### Quit Control

Click the Control menu-bar icon and choose **Quit**. If the app was registered as a login item, quitting it stops the current instance but does not remove the login-item setting. Disable **Launch at Login** if you do not want it to start at the next login.

## Project structure

- `Sources/Control/main.swift` — application entry point
- `Sources/Control/ControlDelegate.swift` — menu-bar app lifecycle and login-item behavior
- `Sources/Control/KeyMonitor.swift` — global Control-key monitoring
- `Sources/Control/AppTracker.swift` — running-application tracking
- `Sources/Control/WheelView.swift` — radial wheel rendering and selection
- `Sources/Control/WheelWindowController.swift` — overlay lifecycle and app activation
- `Info.plist` — menu-bar app metadata
- `bundle.sh` — release application bundle script
