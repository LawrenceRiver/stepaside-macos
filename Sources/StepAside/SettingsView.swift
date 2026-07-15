import StepAsideCore
import SwiftUI

enum StepAsidePalette {
    static let paper = Color(red: 0.965, green: 0.949, blue: 0.902)
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.065)
    static let mutedInk = Color(red: 0.35, green: 0.34, blue: 0.31)
    static let yellow = Color(red: 0.96, green: 0.76, blue: 0.20)
    static let blue = Color(red: 0.48, green: 0.70, blue: 0.82)
    static let coral = Color(red: 0.88, green: 0.36, blue: 0.28)
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                permissionSection
                arrangementSection
                launchSection
                resultSection
                footer
            }
            .padding(30)
        }
        .frame(minWidth: 570, minHeight: 650)
        .background(StepAsidePalette.paper)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("STEP ASIDE.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .tracking(-1.4)
                    .foregroundStyle(StepAsidePalette.ink)
                Text("One click. Every window gets a place.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(StepAsidePalette.mutedInk)
            }
            Spacer(minLength: 12)
            WindowLaneMark()
                .frame(width: 112, height: 74)
                .accessibilityHidden(true)
        }
    }

    private var permissionSection: some View {
        SectionCard(accent: model.permissionGranted ? StepAsidePalette.yellow : StepAsidePalette.coral) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: model.permissionGranted ? "checkmark.seal.fill" : "hand.raised.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(StepAsidePalette.ink)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 7) {
                    Text(model.permissionGranted ? "Accessibility is ready" : "Allow window control")
                        .font(.system(size: 17, weight: .bold))
                    Text(model.permissionGranted
                         ? "StepAside can move and resize ordinary windows on the current desktop."
                         : "macOS requires Accessibility permission before StepAside can arrange windows.")
                        .font(.system(size: 13))
                        .foregroundStyle(StepAsidePalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        if !model.permissionGranted {
                            Button("Request permission") { model.requestPermission() }
                                .buttonStyle(PrimaryButtonStyle())
                                .accessibilityLabel("Request Accessibility permission")
                        }
                        Button("Open System Settings") { model.openPermissionSettings() }
                            .buttonStyle(.link)
                            .accessibilityLabel("Open Accessibility settings")
                    }
                }
            }
        }
    }

    private var arrangementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ARRANGEMENT")

            Picker("Window spacing", selection: Binding(
                get: { model.spacing },
                set: { model.setSpacing($0) }
            )) {
                ForEach(SpacingPreference.allCases, id: \.self) { spacing in
                    Text(spacing.label).tag(spacing)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Window spacing")

            HStack {
                Label("Global shortcut", systemImage: "command")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.hotKeyLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay { Rectangle().stroke(StepAsidePalette.ink, lineWidth: 1.5) }
                    .accessibilityLabel("Global shortcut \(model.hotKeyAccessibleLabel)")
            }
            .padding(.top, 4)
        }
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("STARTUP")
            Toggle("Launch StepAside when I log in", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .accessibilityLabel("Launch StepAside at login")

            if let error = model.launchError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(StepAsidePalette.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var resultSection: some View {
        SectionCard(accent: StepAsidePalette.blue) {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("LATEST RESULT")
                Text(model.latestResult)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(StepAsidePalette.ink)
                    .accessibilityLabel("Latest result: \(model.latestResult)")
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("StepAside \(model.version)")
            Spacer()
            Text("Local only · no screen recording · no analytics")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(StepAsidePalette.mutedInk)
        .textCase(.uppercase)
        .accessibilityElement(children: .combine)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(StepAsidePalette.mutedInk)
    }
}

private struct WindowLaneMark: View {
    var body: some View {
        HStack(spacing: 5) {
            StepAsidePalette.yellow
                .overlay { Rectangle().stroke(StepAsidePalette.ink, lineWidth: 2) }
            VStack(spacing: 5) {
                StepAsidePalette.blue
                    .overlay { Rectangle().stroke(StepAsidePalette.ink, lineWidth: 2) }
                StepAsidePalette.coral
                    .overlay { Rectangle().stroke(StepAsidePalette.ink, lineWidth: 2) }
            }
        }
    }
}

private struct SectionCard<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            accent.frame(width: 10)
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.opacity(0.36))
        .overlay { Rectangle().stroke(StepAsidePalette.ink, lineWidth: 1.5) }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(StepAsidePalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(StepAsidePalette.yellow.opacity(configuration.isPressed ? 0.72 : 1))
            .overlay { Rectangle().stroke(StepAsidePalette.ink, lineWidth: 1.5) }
    }
}

extension SpacingPreference {
    fileprivate var label: String {
        switch self {
        case .compact: "Compact · 8 pt"
        case .balanced: "Balanced · 12 pt"
        case .airy: "Airy · 18 pt"
        }
    }
}
