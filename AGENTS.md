# Control — macOS Weapon Wheel App Switcher

## Overview

A menu bar agent (no Dock icon) that shows a radial wheel of running applications when the user holds the Control key for 100ms. The user moves the mouse toward an app and releases Control to switch to it.

**Stack**: Swift, AppKit, Core Graphics
**Build**: Swift Package Manager → .app bundle via `bundle.sh`
**Target**: macOS 13+

---

## File Structure

```
Control/
├── AGENT.md
├── Package.swift
├── bundle.sh
├── Info.plist
└── Sources/
    └── Control/
        ├── main.swift
        ├── ControlDelegate.swift
        ├── KeyMonitor.swift
        ├── WheelWindowController.swift
        ├── WheelView.swift
        └── AppTracker.swift
```

---

## Package.swift

- Single executable target named `Control`
- Platform: `.macOS(.v13)`
- No external dependencies

---

## Info.plist

- `CFBundleIdentifier`: `com.control.Control`
- `LSUIElement`: `true` (hides from Dock, no Cmd+Tab entry)
- `CFBundleName`: `Control`
- `CFBundleExecutable`: `Control`

---

## bundle.sh

Shell script that:
1. Runs `swift build -c release`
2. Creates directory structure: `build/Control.app/Contents/MacOS/` and `build/Control.app/Contents/Resources/`
3. Copies the binary from `.build/release/Control` → `build/Control.app/Contents/MacOS/Control`
4. Copies `Info.plist` → `build/Control.app/Contents/Info.plist`

---

## main.swift — Entry Point

```swift
import Cocoa

let app = NSApplication.shared
let delegate = ControlDelegate()
app.delegate = delegate
app.run()
```

No storyboard, no NIB. Manual `NSApplication` setup.

---

## ControlDelegate.swift — NSApplicationDelegate

**On `applicationDidFinishLaunching`:**

1. Set `NSApp.setActivationPolicy(.accessory)` — menu bar agent, no Dock icon.

2. Create a menu bar status item:
   - `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)`
   - Icon: `NSImage(systemSymbolName: "circle.grid.cross")`, fallback to `"⊕"` text.
   - Menu with "About Control" and "Quit" items.

3. Initialize `AppTracker`.

4. Initialize `WheelWindowController(appTracker:)`.

5. Initialize `KeyMonitor` with three callbacks:
   - `onLongPress` → `wheelController.showWheel()`
   - `onRelease` → `wheelController.selectAndHide()`
   - `onCancel` → `wheelController.cancelAndHide()`

6. Check Accessibility permission:
   - Call `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true`.
   - If not trusted, show an `NSAlert` telling the user to grant access in System Settings → Privacy & Security → Accessibility, then relaunch.

---

## KeyMonitor.swift — Global Key Detection

**Properties:**
- `holdDuration: TimeInterval = 0.1` (100ms)
- `longPressTimer: Timer?`
- `isWheelShowing: Bool = false`
- Three callback closures: `onLongPress`, `onRelease`, `onCancel`
- Monitor references for cleanup: `globalFlagsMonitor`, `localFlagsMonitor`, `globalKeyMonitor`, `localKeyMonitor`

**Setup — install four event monitors:**

1. **Global flagsChanged** — `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` → fires when other apps are focused.
2. **Local flagsChanged** — `NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)` → fires when our overlay is focused.
3. **Global keyDown** — `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` → cancel on any key press.
4. **Local keyDown** — `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` → same, when overlay is focused.

**flagsChanged handler:**

```
if Control is down AND wheel is not showing:
    invalidate any existing timer
    start a 100ms Timer
    on timer fire → set isWheelShowing = true, call onLongPress()

if Control is up:
    invalidate timer
    if isWheelShowing:
        set isWheelShowing = false
        call onRelease()
```

Check Control state with: `event.modifierFlags.contains(.control)`

**keyDown handler:**

```
if isWheelShowing:
    invalidate timer
    set isWheelShowing = false
    call onCancel()
```

This prevents conflicts with shortcuts like Ctrl+C — any real key press cancels the wheel.

**Cleanup:** Remove all four monitors in `deinit`.

---

## AppTracker.swift — Running App Tracking

**Properties:**
- `recentApps: [NSRunningApplication]` — MRU-ordered list
- `maxApps = 6`

**Init:**
1. Seed `recentApps` from `NSWorkspace.shared.runningApplications`, filtered by `isEligible()`.
2. Observe `NSWorkspace.didActivateApplicationNotification` → `appDidActivate()`.
3. Observe `NSWorkspace.didTerminateApplicationNotification` → `appDidTerminate()`.

**`isEligible(_ app:) -> Bool`:**
- `app.activationPolicy == .regular` (GUI apps only, no background daemons)
- `app.bundleIdentifier != Bundle.main.bundleIdentifier` (exclude ourselves)
- `!app.isTerminated`

**`appDidActivate`:** Extract `NSRunningApplication` from notification's `userInfo[NSWorkspace.applicationUserInfoKey]`. If eligible, remove from list by PID, insert at index 0. Trim to `maxApps * 2` to avoid unbounded growth.

**`appDidTerminate`:** Remove from list by PID.

**`topApps() -> [NSRunningApplication]`:** Remove terminated apps, return `prefix(maxApps)`.

---

## WheelWindowController.swift — Overlay Window

**Properties:**
- `overlayWindow: NSWindow?`
- `wheelView: WheelView?`
- `globalMouseMonitor: Any?`
- `localMouseMonitor: Any?`
- `appTracker: AppTracker` (injected via init)

### `showWheel()`

1. Get apps from `appTracker.topApps()`. Return if empty.
2. Find the screen containing the mouse cursor:
   ```swift
   let mouseLocation = NSEvent.mouseLocation
   let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
       ?? NSScreen.main ?? NSScreen.screens[0]
   ```
3. Create `NSWindow`:
   - `contentRect`: `screen.frame`
   - `styleMask`: `.borderless`
   - `backing`: `.buffered`
   - `level`: `.floating`
   - `isOpaque`: `false`
   - `backgroundColor`: `.clear`
   - `hasShadow`: `false`
   - `ignoresMouseEvents`: `false`
   - `acceptsMouseMovedEvents`: `true`
   - `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary]`
4. Convert mouse location to window coordinates:
   ```swift
   let centerInWindow = NSPoint(
       x: mouseLocation.x - screen.frame.origin.x,
       y: mouseLocation.y - screen.frame.origin.y
   )
   ```
5. Create `WheelView(frame: screen.frame, apps: apps, center: centerInWindow)` and set as `contentView`.
6. `window.makeKeyAndOrderFront(nil)`, `NSApp.activate(ignoringOtherApps: true)`.
7. Install mouse-move monitors (global + local) that call `updateMousePosition()`.
8. Call `updateMousePosition()` once immediately for initial state.

### `selectAndHide()`

1. If `wheelView?.selectedApp` exists, capture it, call `hideWheel()`, then after 50ms delay activate the app:
   ```swift
   app.activate(options: [.activateIgnoringOtherApps])
   ```
2. If no selection, just `hideWheel()`.

### `cancelAndHide()`

Call `hideWheel()` (no app switch).

### `hideWheel()` (private)

1. Remove both mouse monitors via `NSEvent.removeMonitor()`.
2. `overlayWindow?.orderOut(nil)`.
3. Nil out `overlayWindow`, `wheelView`, and monitor references.

### `updateMousePosition()` (private)

Convert `NSEvent.mouseLocation` (screen coords) to window coords, call `wheelView.updateSelection(at:)`.

---

## WheelView.swift — Radial Menu (NSView)

**Properties:**
- `apps: [NSRunningApplication]` — set at init
- `wheelCenter: NSPoint` — where the mouse was when wheel appeared
- `wheelRadius: CGFloat = 140` — distance from center to icon positions
- `iconSize: CGFloat = 64`
- `deadZoneRadius: CGFloat = 30` — ignore mouse within this radius of center
- `hoveredIndex: Int? = nil`

**`selectedApp: NSRunningApplication?`** — computed from `hoveredIndex`.

### `updateSelection(at point: NSPoint)`

1. Compute distance from `wheelCenter`. If < `deadZoneRadius`, clear selection, return.
2. Compute angle: `atan2(dy, dx)`. Normalize to 0...2π.
3. First app is positioned at top (π/2). Offset and wrap:
   ```swift
   let sliceAngle = (2 * .pi) / CGFloat(apps.count)
   let startOffset = CGFloat.pi / 2
   var adjusted = angle - startOffset + sliceAngle / 2
   if adjusted < 0 { adjusted += 2 * .pi }
   let newIndex = Int(adjusted / sliceAngle) % apps.count
   ```
4. If changed, set `hoveredIndex`, trigger `needsDisplay = true`.

### `draw(_ dirtyRect:)` — Core Graphics drawing

**Layer 1 — Dim backdrop:**
- Fill entire bounds with `black @ 0.35 alpha`.

**Layer 2 — Wheel background:**
- `outerRadius = wheelRadius + iconSize/2 + 30`
- Fill a circle centered at `wheelCenter` with `black @ 0.6 alpha`.
- Stroke thin ring: `white @ 0.15 alpha`, lineWidth `1.5`.

**Layer 3 — App segments** (loop over apps):

Each app is positioned at angle: `startOffset + sliceAngle * i` where `startOffset = π/2` (top).

**If hovered:**
- Draw a wedge highlight between `deadZoneRadius` and `outerRadius`, spanning `±sliceAngle/2` around the app's angle. Fill with `white @ 0.15 alpha`.
- Offset icon position outward by 8pt.
- Draw icon at `iconSize * 1.15`.
- Label font: bold, 12pt.
- Label color: white.

**If not hovered:**
- Icon at normal `iconSize`.
- Label font: system, 10pt.
- Label color: `white @ 0.8 alpha`.

**Icon:** `app.icon?.draw(in: iconRect)` — `NSRunningApplication.icon` returns `NSImage`.

**Label:** `app.localizedName ?? "?"` — draw as `NSAttributedString` centered below the icon.

**Layer 4 — Center dot:**
- 8pt circle at `wheelCenter`, fill `white @ 0.5 alpha`.

---

## Build & Run

```bash
cd Control
swift build -c release
./bundle.sh
open ./build/Control.app

# Permanent install
cp -r ./build/Control.app /Applications/
```

First launch will prompt for Accessibility permission. Grant it, then relaunch.

---

## Implementation Order

1. **Scaffold** — Package.swift, main.swift, Info.plist, bundle.sh, ControlDelegate with menu bar icon. Verify it builds and shows a menu bar icon.
2. **KeyMonitor** — Detect Control long-press (100ms) and release. Log to console to verify timing.
3. **AppTracker** — List running apps, track MRU order via workspace notifications. Cap at 6. Log app list on each activation change.
4. **WheelWindowController** — Transparent overlay window appears on long-press, disappears on release. No drawing yet, just the window lifecycle.
5. **WheelView layout** — Draw app icons in a circle with labels. Static, no hover interaction.
6. **WheelView selection** — Track mouse angle, highlight hovered segment with wedge fill, enlarged icon, bold label.
7. **App switching** — Activate selected app on Control release. Cancel (no switch) on any keyDown.
8. **Polish** — Smooth hover animations, edge cases (1 app, 2 apps layout), multi-monitor testing.
9. **Packaging** — Verify bundle.sh output, test Accessibility permission persistence across rebuilds.

---

## Edge Cases

- **0 apps**: Don't show the wheel.
- **1 app**: Single icon at top center, full 360° selection zone.
- **Control tapped quickly** (< 100ms): Timer never fires, wheel never shows, no disruption.
- **Ctrl+C / Ctrl+V etc.**: keyDown monitor cancels wheel before the shortcut executes.
- **Multi-monitor**: Wheel appears on screen containing mouse cursor at trigger time.
- **Full-screen apps**: `.activate(options: [.activateIgnoringOtherApps])` handles Space switching.
- **App quits while wheel is showing**: `topApps()` filters terminated apps; wheel draws whatever remains.