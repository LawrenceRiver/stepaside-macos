# StepAside Design Specification

## Product definition

StepAside is a native macOS menu-bar utility that arranges the ordinary windows visible in the current Space into a dense, non-overlapping workspace. It is intentionally a single-purpose product: one click makes every eligible window usable at once.

The public GitHub repository name is `stepaside-macos`. The app and local project directory use the brand name `StepAside`.

## Goals

- Arrange eligible windows on the current Space with one left-click or a global shortcut.
- Keep every arranged window inside its display's visible frame, with no overlap.
- Preserve a practical size for each window rather than forcing a rigid grid.
- Arrange each display independently and never move a window to another display or Space.
- Finish a typical arrangement of up to ten normal windows in about one second.
- Let the user undo the most recent arrangement.
- Require only the macOS Accessibility permission. The app does not record the screen, monitor keystrokes, or use the network.
- Produce a signed-ready `.app`, `.dmg`, complete icon set, documentation, and release checklist.

## Non-goals

- Managing inactive Spaces.
- Replacing Mission Control, Stage Manager, or the Dock.
- Persistently enforcing a layout after the user moves a window.
- Reading window contents, messages, passwords, or screen pixels.
- Moving minimized, hidden, full-screen, modal, system, desktop, menu-bar, or nonstandard overlay windows.
- Shipping CrawlCar features inside StepAside.

## User experience

### Menu-bar behavior

StepAside runs as an accessory app with no Dock icon.

- Left-click the status item: arrange the current Space immediately.
- Press `Control-Option-S`: perform the same action. The shortcut is editable.
- Right-click the status item: show a native menu with Arrange Now, Undo Last Arrangement, Launch at Login, Settings, and Quit.
- While arranging, the status icon uses a short in-place motion so repeated clicks do not start concurrent transactions.
- On completion, a nonactivating top-right HUD reports a concise result such as `6 windows · arranged`.
- Partial results identify the skipped count and make the reason available in Settings without interrupting the user's work.

### First run

The first run opens a small onboarding window that explains why Accessibility permission is needed and offers one system-provided path to grant it. StepAside never claims that permission has been granted until `AXIsProcessTrusted` confirms it.

After permission is granted, the onboarding window offers a local demo using StepAside's own sample panels. It does not move other app windows until the user performs the first explicit Arrange action.

### Settings

Settings stays deliberately small:

- Editable global shortcut.
- Spacing: Compact (8 pt), Balanced (12 pt, default), or Airy (18 pt).
- Launch at Login toggle.
- Permission status and a button to open the relevant System Settings page.
- Recent result summary and app version.

User-maintained app exclusion lists, saved layouts, cloud sync, analytics, and themes are excluded from version 1.

## Visual direction

The supplied Numenu reference informs only broad design principles: editorial confidence, warm paper-like neutrals, strong black typography, crisp rectangular color fields, and a small set of yellow, pale blue, and coral accents. StepAside does not reuse the reference's logo, assets, web layout, text, or components.

The menu-bar item and context menu remain native. The onboarding, Settings window, HUD, and release artwork use an original "editorial utility" system:

- Warm ivory surface and near-black text.
- Large status typography paired with compact system text.
- Straight-edged information bands with limited corner rounding where macOS controls require it.
- Yellow for ready/success, blue for information, and coral for attention or partial completion.
- No gradients, glass imitation, decorative shadows, or copied web navigation patterns.

The app icon is a realistic three-dimensional macOS icon: a compact set of dark window slabs moving outward into a precise edge-aligned arrangement, on an ivory ground with restrained yellow, blue, and coral faces. It must remain legible at 16 px and use an original silhouette.

## Layout approaches considered

### Equal grid

Equal cells are predictable but leave awkward empty cells for many window counts and ignore useful differences in window aspect ratios.

### Adaptive justified rows — selected

The selected approach partitions the ordered windows into complete rows. Each row fills the available width, while row height and window width adapt to current aspect ratio, declared minimum size, and movement distance. This creates a full, balanced desktop without privileging the active app.

### Focus mosaic

A large active window with smaller secondary windows is useful for focused work but conflicts with the product promise that all windows receive comparable operational space.

## Window eligibility and discovery

`WindowDiscoveryService` combines public Core Graphics and Accessibility information:

1. `CGWindowListCopyWindowInfo` with the on-screen-only option supplies the windows actually visible in the current user session and Space.
2. Windows are filtered to normal application layers with useful bounds and an owning process.
3. `AXUIElement` supplies role, subrole, minimized state, movability, resizability, position, and size.
4. Core Graphics records are matched to Accessibility windows by owner PID, title, and bounds through a deterministic matcher. Ambiguous matches are skipped rather than risking the wrong window.

Eligible windows must be visible, ordinary application windows that can be moved. Resizable windows participate normally. Movable but non-resizable windows are treated as fixed-size constraints. StepAside itself and known system surfaces are excluded.

No private SkyLight or WindowServer API is used.

## Layout engine

The pure Swift `LayoutEngine` receives immutable window and display snapshots and returns placements plus explicit skip reasons. It does not call macOS APIs.

### Coordinate and display rules

- Work is grouped by the display containing the largest portion of each current window.
- Each display uses `NSScreen.visibleFrame`, respecting the menu bar and Dock.
- A selected spacing value is applied both as an outer margin and between windows.
- Existing top-to-bottom, then left-to-right order is preserved where possible to reduce cognitive and physical movement.

### Adaptive row solver

For each display, the solver enumerates feasible row partitions. Candidate cost combines:

- Aspect-ratio distortion from the current window shape.
- Distance from the current window center.
- Difference between row heights.
- Minimum-size pressure.
- Unused area.

Partitions with overlap, out-of-bounds frames, or hard minimum-size violations are rejected. The lowest-cost deterministic partition wins.

Movable but non-resizable windows are placed first as fixed constraints. Their frames are subtracted from the available area, producing free rectangles for the normal solver. If physical minimum sizes make a complete layout impossible, the engine arranges the largest feasible set and returns a reason for every skipped window. It never creates an overlap to pretend that arrangement succeeded.

### Safety invariants

Every successful placement must satisfy:

- Frame is contained in exactly one target display's visible frame.
- Frame does not intersect another successful placement after accounting for spacing.
- Width and height meet the window's known minimums.
- The target display equals the source display.
- Results are deterministic for identical inputs.

## Arrangement transaction

`ArrangementCoordinator` owns one transaction at a time:

1. Confirm Accessibility trust.
2. Discover and snapshot eligible windows.
3. Calculate a layout off the main thread.
4. Save original frames for Undo.
5. Apply sizes and positions through `WindowMutator` in a bounded sequence.
6. Read frames back after a short settle interval.
7. Run one collision-repair pass for apps that constrained or shifted their frames.
8. Publish a success, partial, no-op, permission, or failure result to the status item and HUD.

A new Arrange action is ignored while a transaction is applying frames. Undo is itself transactional and only restores windows that still refer to the same running app/window match. Quitting the app discards the in-memory undo snapshot.

## Architecture

The app uses Swift 6, AppKit, and SwiftUI, targeting macOS 14 or later. It has no third-party runtime dependencies and no network client.

- `StepAsideApp`: application lifecycle and accessory activation policy.
- `StatusItemController`: left/right-click routing, icon state, and native menu.
- `AccessibilityGate`: trust status and permission prompt.
- `WindowDiscoveryService`: current-Space window collection and matching.
- `WindowSystemClient`: protocol for querying and changing Accessibility frames.
- `LayoutEngine`: platform-independent placement calculation.
- `ArrangementCoordinator`: transaction, undo, verification, and result mapping.
- `GlobalHotKeyService`: system hotkey registration without key logging.
- `LaunchAtLoginService`: `SMAppService` integration.
- `HUDController`: nonactivating completion message.
- `SettingsModel` and SwiftUI views: onboarding and preferences.

The repository is a Swift Package with an executable target and test target. Release scripts assemble the release binary, `Info.plist`, resources, and `.icns` into `StepAside.app`, apply ad-hoc or supplied Developer ID signing, and build a DMG. This keeps builds reproducible without checking in a generated Xcode project.

## Data and privacy

StepAside stores only local preferences: shortcut, spacing, launch-at-login setting, onboarding completion, and the latest nonsensitive result summary. Window titles are used transiently for matching and never persisted or logged in release builds.

There is no analytics, crash-upload service, update network client, screen capture, clipboard access, input monitoring, or Full Disk Access request. Accessibility permission remains revocable in System Settings.

## Error handling

- Missing permission: do not attempt arrangement; show permission guidance.
- No eligible windows: show a neutral no-op HUD.
- Ambiguous Core Graphics/Accessibility match: skip and record a generic reason without retaining the title.
- App rejects a size or position: verify, repair once, then report partial completion.
- Window closes during the transaction: drop it and continue.
- Display configuration changes during the transaction: abort before applying or roll back frames already changed where still possible.
- Hotkey conflict: retain menu-bar operation and request a different shortcut in Settings.

## Testing and acceptance

### Automated tests

- Layout property tests for 1–20 windows across common display sizes and aspect ratios.
- Assertions for containment, spacing, non-overlap, minimum size, determinism, and source-display preservation.
- Fixtures for odd window counts, non-resizable constraints, infeasible density, Dock positions, notched/menu-bar frames, and multiple displays.
- Matching tests for duplicate titles, missing titles, changing bounds, and ambiguous candidates.
- Coordinator tests with a fake window system for success, partial apply, disappearing windows, verification repair, re-entrancy, and undo.
- Preference, shortcut validation, and result-copy tests.

### Manual acceptance

- Fresh install and Accessibility permission flow.
- Left-click, shortcut, right-click, and Undo behavior.
- Finder, Safari/Chrome, Terminal, Codex, and a multi-window app on one Space.
- Two-display arrangement without cross-display movement.
- Minimized, modal, full-screen, non-resizable, and rapidly closing windows.
- Menu bar and Dock in supported positions.
- Dark Mode, increased contrast, reduced motion, VoiceOver labels, and keyboard navigation.

### Release gate

The project is ready for GitHub release when:

- All automated tests pass from a clean clone.
- Release and DMG scripts complete locally.
- A smoke-tested ad-hoc signed build launches on the development Mac.
- The icon is complete at all macOS sizes and passes small-size inspection.
- README, privacy statement, license, architecture notes, contributing instructions, changelog, and release checklist are present.
- No private APIs, credentials, absolute developer paths, generated caches, or unrelated workspace files are committed.

Developer ID signing, notarization, creating the public GitHub repository, and pushing a release require the user's Apple/GitHub credentials and remain explicit external release steps.
