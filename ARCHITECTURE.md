# Architecture

StepAside separates platform access from deterministic layout logic so the safety properties are testable without moving real windows.

## Components

- `StepAsideCore` contains immutable geometry, models, matching, layout, outcome copy, and the transaction coordinator.
- `MacWindowSystem` is the only concrete window adapter. It uses public Core Graphics for the on-screen window list and public Accessibility APIs for window state and frame mutation.
- `StatusItemController`, `HUDController`, and `SettingsController` own the menu-bar interaction, nonactivating result message, onboarding, and preferences.
- `GlobalHotKeyService` registers one system hot key; it does not install an event tap.
- `LaunchAtLoginService` wraps `SMAppService.mainApp`.

## Discovery and matching

`CGWindowListCopyWindowInfo` is called with `optionOnScreenOnly` and `excludeDesktopElements`. Records must be on the normal application layer, sufficiently large, visible, and owned by another process.

For each owner PID, Accessibility supplies standard, nonmodal, nonminimized application windows. Records are matched by PID, normalized title, and geometric distance. A match is accepted only when it is uniquely defensible; an ambiguous untitled pair is skipped rather than risking movement of the wrong window.

Full-screen windows are excluded when their bounds cover at least 98% of a display. StepAside itself, desktop surfaces, menu extras, and nonstandard overlays are not eligible.

## Coordinates and displays

Core Graphics and Accessibility use a top-left global coordinate space, while `NSScreen` frames use AppKit's bottom-left coordinate space. `DisplayGeometry` converts `NSScreen.visibleFrame` using the display's `CGDisplayBounds`, preserving menu-bar and Dock insets on primary, secondary, and left-of-primary displays.

Every window remains assigned to the display containing the largest area of its source frame. Displays are solved independently.

## Layout invariants

The adaptive row solver evaluates deterministic row partitions and scores aspect distortion, movement, row balance, minimum-size pressure, and unused area. Non-resizable movable windows become fixed obstacles; the remaining free rectangles are solved around them.

Every successful placement must:

- remain inside the source display's visible frame;
- meet the window's known minimum width and height;
- preserve the requested outer and inter-window spacing;
- avoid every other successful placement and fixed obstacle;
- be deterministic for identical input.

If all windows cannot fit, the engine returns the largest feasible layout with an explicit skip reason. It never overlaps windows to manufacture a success result.

## Transaction and Undo

`ArrangementCoordinator` is an actor and accepts one transaction at a time. It discovers a snapshot, calculates the layout, retains original frames in memory, applies frames, waits briefly for application constraints, reads frames back, and retries a rejected frame once. A later Undo restores surviving matched windows from the in-memory snapshot.

## Public API boundary

The project does not link private `CGS`, `SLS`, SkyLight, or WindowServer symbols. Release validation scans the final executable for those imports. StepAside does not control inactive Spaces because macOS provides no supported public API for silently rearranging them.

