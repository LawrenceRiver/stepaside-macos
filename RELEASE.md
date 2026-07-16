# Release guide

This repository can produce a universal, ad-hoc signed release candidate without private credentials. Public distribution additionally requires the maintainer's Apple Developer and GitHub credentials.

## Local release candidate

```bash
rm -rf .build dist
make test
make dmg
```

Verify the outputs:

```bash
codesign --verify --deep --strict --verbose=2 dist/StepAside.app
hdiutil verify dist/StepAside.dmg
file dist/StepAside.app/Contents/MacOS/StepAside
```

The executable must be universal `arm64` + `x86_64`. The metadata must contain identifier `com.lawrenceriver.stepaside`, version `1.0.0`, minimum macOS `14.0`, and `LSUIElement = true`.

## Manual acceptance

Run these checks on a noncritical desktop and use Undo immediately after the movement tests:

- [ ] Fresh-install Accessibility onboarding and revocation path
- [ ] No Dock icon; menu-bar item remains available
- [ ] Left-click arrangement and top-right nonactivating result HUD
- [ ] `Control-Option-S` arrangement
- [ ] Right-click native menu and Undo
- [ ] Finder, Safari/Chrome, Terminal, and a multi-window app
- [ ] Two-display source-display preservation, when a second display is available
- [ ] Minimized, full-screen, modal, constrained, and rapidly closing windows
- [ ] Compact, Balanced, and Airy preference persistence
- [ ] Launch at Login toggle
- [ ] Reduce Motion, increased contrast, keyboard navigation, and VoiceOver labels

Do not record window titles or personal screen content in this file.

## Developer ID and notarization

1. Install a valid `Developer ID Application` certificate in the login keychain.
2. Build with `CODESIGN_IDENTITY="Developer ID Application: ..." make dmg`.
3. Submit the DMG with `xcrun notarytool submit dist/StepAside.dmg --keychain-profile PROFILE --wait`.
4. Staple with `xcrun stapler staple dist/StepAside.dmg`.
5. Validate with `spctl --assess --type open --context context:primary-signature -v dist/StepAside.dmg`.

Certificates, Apple credentials, notary profiles, and provisioning material must never be committed.

## GitHub publication

The public repository is [LawrenceRiver/stepaside-macos](https://github.com/LawrenceRiver/stepaside-macos).

After review, push the verified `main` branch and release tag. Publish each release candidate as a GitHub prerelease for that tag and attach `StepAside.dmg`. Record the DMG's SHA-256 value in the release notes or attach a checksum file alongside the DMG. Build scripts intentionally do not use GitHub credentials or publish artifacts.

## 2026-07-16 local verification record

- macOS 26.5.1, Apple Silicon
- Swift 6.3.3 / Xcode SDK 26.5
- 24 automated tests passed
- Settings/onboarding launched as a menu-bar-only app with no Dock icon
- `Control-Option-S` invoked the packaged app's Accessibility guard
- The system Accessibility permission dialog displayed the correct StepAside identity and guidance
- Universal release build completed
- Strict ad-hoc code-sign verification passed
- DMG checksum verification passed
- Final executable contained no CGS, SLS, or SkyLight imports
