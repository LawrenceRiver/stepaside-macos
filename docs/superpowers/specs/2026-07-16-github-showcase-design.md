# StepAside GitHub Showcase Design

## Goal

Publish `LawrenceRiver/stepaside-macos` as a complete public open-source product page with an honest product description, working badges and links, MIT licensing, test evidence, release artifacts, and one privacy-safe real-use overview image.

## README structure

The README opens with the existing app icon, a one-sentence product promise, and badges for macOS 14+, Swift 6, CI, release, and MIT. A real screenshot follows, showing multiple local dummy windows after StepAside arranged them. The remaining sections cover the one-click workflow, capabilities, installation, permission boundary, build and tests, architecture, privacy, release status, and contribution links.

## Visual rule

The overview image must come from the actual built app operating on local dummy windows. It must not contain the user's files, browser pages, notifications, credentials, or private desktop content. The existing generated 3D icon remains the brand anchor.

## GitHub metadata and publishing

Repository description: `One-click, privacy-first window tiling for the current macOS desktop.`

Topics: `macos`, `swift`, `swiftui`, `appkit`, `window-manager`, `productivity`, `menu-bar-app`, `accessibility`.

Push local `main` and tag `v1.0.0-rc1` to the empty public repository. Create a prerelease containing `StepAside.dmg`; preserve the MIT license already tracked in `LICENSE`.

## Acceptance

- README image and all badge links resolve from GitHub.
- `make test` passes from the exact pushed commit.
- Repository metadata and topics match this design.
- `main`, `v1.0.0-rc1`, and the release artifact are visible publicly.
