import AppKit
import StepAsideCore
import SwiftUI

@MainActor
final class HUDController {
    private let panel: NSPanel
    private var dismissalTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 356, height: 86),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovable = false
        panel.ignoresMouseEvents = true
    }

    func show(_ outcome: ArrangementOutcome) {
        show(headline: outcome.headline, tone: .init(outcome.status))
    }

    func show(headline: String, tone: HUDTone) {
        dismissalTask?.cancel()
        panel.contentView = NSHostingView(rootView: HUDMessageView(headline: headline, tone: tone))
        positionPanel()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                panel.animator().alphaValue = 1
            }
        }

        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled, let self else { return }
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                self.panel.orderOut(nil)
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.12
                    self.panel.animator().alphaValue = 0
                }, completionHandler: {
                    Task { @MainActor [weak self] in self?.panel.orderOut(nil) }
                })
            }
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let frame = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - frame.width - 18,
            y: visible.maxY - frame.height - 14
        ))
    }
}

enum HUDTone: Sendable {
    case success
    case information
    case attention

    init(_ status: ArrangementOutcome.Status) {
        switch status {
        case .success, .undone: self = .success
        case .partial, .failed: self = .attention
        case .noWindows, .busy, .nothingToUndo: self = .information
        }
    }

    fileprivate var color: Color {
        switch self {
        case .success: StepAsidePalette.yellow
        case .information: StepAsidePalette.blue
        case .attention: StepAsidePalette.coral
        }
    }
}

private struct HUDMessageView: View {
    let headline: String
    let tone: HUDTone

    var body: some View {
        HStack(spacing: 0) {
            tone.color
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("STEP ASIDE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(StepAsidePalette.mutedInk)

                Text(headline)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(StepAsidePalette.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .background(StepAsidePalette.paper)
        .overlay {
            Rectangle()
                .stroke(StepAsidePalette.ink, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headline)
    }
}

