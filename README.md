# StepAside

![StepAside app icon](Brand/AppIcon-1024.png)

StepAside is a focused macOS menu-bar utility: one click arranges the ordinary windows visible on the current desktop into a dense, usable, non-overlapping layout.

It is built with Swift 6, AppKit, and SwiftUI, has no third-party runtime dependencies, and targets macOS 14 or later.

## What it does

- Left-click the menu-bar icon to arrange the current desktop.
- Press `Control-Option-S` for the same action.
- Right-click for Arrange, Undo, Launch at Login, Settings, and Quit.
- Arrange each display independently without moving windows between displays.
- Preserve practical window sizes, spacing, and source-display assignment.
- Verify applied frames and retry once when an app constrains a requested size.
- Restore the most recent arrangement with Undo.

StepAside intentionally does not manage inactive Spaces, move full-screen or minimized windows, read window contents, record the screen, or send data over the network.

## Install from a release

1. Open `StepAside.dmg`.
2. Drag StepAside to Applications.
3. Launch StepAside and follow the Accessibility permission guide.
4. Return to StepAside Settings after granting permission; macOS permission changes remain fully revocable in System Settings.

Unsigned or ad-hoc signed development builds may require a right-click followed by **Open**. Public distribution should use a Developer ID signature and Apple notarization as described in [RELEASE.md](RELEASE.md).

## Build from source

Requirements:

- macOS 14+
- Xcode with Swift 6.2 or later
- Command Line Tools selected with `xcode-select`

```bash
make test
make app
make dmg
```

Outputs are written to `dist/StepAside.app` and `dist/StepAside.dmg`. The default build is a universal `arm64` + `x86_64` binary and uses an ad-hoc signature. To sign with Developer ID:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make dmg
```

## How it works

StepAside combines the public Core Graphics window list with the macOS Accessibility API. A deterministic matcher associates visible window records with movable Accessibility windows; ambiguous matches are skipped. A pure Swift layout engine then solves each display independently and guarantees containment, minimum size, spacing, and non-overlap before frames are applied.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design and [PRIVACY.md](PRIVACY.md) for the local data policy.

## Repository

Recommended public repository name: `stepaside-macos`.

## License

MIT. See [LICENSE](LICENSE).

