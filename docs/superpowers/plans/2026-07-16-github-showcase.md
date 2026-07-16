# StepAside GitHub Showcase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish StepAside as a polished, verifiable public GitHub project.

**Architecture:** Keep product code unchanged. Add one real-use image under `docs/images`, rewrite the root README around verifiable local behavior, then publish the existing clean `main` and release tag to the empty repository.

**Tech Stack:** Markdown, GitHub Actions badges, GitHub CLI, macOS window capture, Swift test suite.

## Global Constraints

- The overview image contains only local dummy windows and no personal desktop data.
- Claims must match the tested macOS 14+, Swift 6, AppKit/SwiftUI implementation.
- Public release binaries remain ad-hoc signed and must be labeled prerelease.
- MIT licensing remains in the tracked root `LICENSE`.

---

### Task 1: Real-use overview

**Files:**
- Create: `docs/images/stepaside-overview.png`

**Interfaces:**
- Consumes: `dist/StepAside.app`, local dummy windows, current desktop only.
- Produces: a GitHub-renderable PNG referenced by the README.

- [ ] **Step 1:** Launch local dummy windows with non-sensitive labels.
- [ ] **Step 2:** Run the actual StepAside arrange action.
- [ ] **Step 3:** Capture only the dummy-window region and inspect the PNG for privacy and legibility.

### Task 2: README product page

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: `docs/images/stepaside-overview.png`, existing `ARCHITECTURE.md`, `PRIVACY.md`, `RELEASE.md`, and `LICENSE`.
- Produces: a complete public landing page with working relative links.

- [ ] **Step 1:** Add CI, release, platform, Swift, and MIT badges with `LawrenceRiver/stepaside-macos` URLs.
- [ ] **Step 2:** Add the real overview image, concise workflow, installation, tests, architecture, privacy, and release sections.
- [ ] **Step 3:** scan for stale placeholder repository language and broken relative links.

### Task 3: Verify and publish

**Files:**
- Modify remotely: GitHub repository metadata, topics, tag, and release.

**Interfaces:**
- Consumes: the clean local `main`, `v1.0.0-rc1`, and `dist/StepAside.dmg`.
- Produces: public `LawrenceRiver/stepaside-macos` default branch and prerelease.

- [ ] **Step 1:** Run `make test` and verify `git diff --check` passes.
- [ ] **Step 2:** Commit README and image changes, add the empty GitHub repository as `origin`, and push `main` plus `v1.0.0-rc1`.
- [ ] **Step 3:** Set the exact description and topics from the design, create the prerelease, and verify public URLs and Actions state.
