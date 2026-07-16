# StepAside GitHub Showcase Design

## Goal

Publish `LawrenceRiver/stepaside-macos` as a complete public open-source product page with an honest product description, working badges and links, MIT licensing, test evidence, release artifacts, and one privacy-safe real-use overview image.

## README structure

The README opens with the existing app icon, a one-sentence product promise, and badges for macOS 14+, Swift 6, CI, release, and MIT. A real screenshot follows, showing five local dummy windows after an AX-trusted local showcase host invoked the repository's production `ArrangementCoordinator` and `LayoutEngine`. The remaining sections cover the one-click workflow, capabilities, installation, permission boundary, build and tests, architecture, privacy, release status, and contribution links.

## Visual rule

The overview image must be a real macOS capture of local dummy windows after the repository's production `ArrangementCoordinator` and `LayoutEngine` calculated and applied the five-window layout through an AX-trusted local showcase host. It is not a concept render or composited mockup. The packaged `StepAside.app` was not authorized by macOS Accessibility/TCC in the capture environment and therefore did not trigger this arrangement; the showcase host is the explicit provenance boundary. The image must not contain the user's files, browser pages, notifications, credentials, or private desktop content. The existing generated 3D icon remains the brand anchor.

## GitHub metadata and publishing

Repository description: `One-click, privacy-first window tiling for the current macOS desktop.`

Topics: `macos`, `swift`, `swiftui`, `appkit`, `window-manager`, `productivity`, `menu-bar-app`, `accessibility`.

Push local `main` and tag `v1.0.0-rc1` to the empty public repository. Create a prerelease containing `StepAside.dmg`; preserve the MIT license already tracked in `LICENSE`.

## Acceptance

- README image and all badge links resolve from GitHub.
- `make test` passes from the exact pushed commit.
- Repository metadata and topics match this design.
- `main`, `v1.0.0-rc1`, and the release artifact are visible publicly.
