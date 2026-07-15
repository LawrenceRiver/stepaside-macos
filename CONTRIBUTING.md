# Contributing

Thanks for helping improve StepAside.

## Development setup

1. Use macOS 14 or later with Xcode and Swift 6.2+.
2. Fork and clone the repository.
3. Create a focused branch.
4. Run `make test` before and after a change.

Use `make app` to assemble an ad-hoc signed application and `make dmg` to exercise the full packaging path.

## Change expectations

- Add a failing test before changing layout, matching, geometry conversion, or coordinator behavior.
- Preserve containment, minimum-size, spacing, non-overlap, determinism, and source-display invariants.
- Treat ambiguous window matches as ineligible.
- Use only documented public macOS APIs. Private CGS, SLS, SkyLight, or WindowServer calls are not accepted.
- Do not add telemetry, network behavior, persistent window titles, screen capture, clipboard reads, or credential access.
- Keep the menu-bar action fast and the primary interaction one click.
- Include VoiceOver labels and respect Reduce Motion in user-facing changes.

## Pull requests

Describe the user-visible change, tests run, and any macOS versions or display configurations exercised. Never include real window titles, screenshots containing private data, credentials, provisioning profiles, notarization secrets, or signing certificates.

