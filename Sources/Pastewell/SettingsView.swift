import SwiftUI

struct PastewellSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: HistoryStore

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            behavior
                .tabItem { Label("Behavior", systemImage: "cursorarrow.click") }
            appearance
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            privacy
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(20)
        .frame(width: 570, height: 440)
        .tint(settings.accentPreset.color)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
    }

    private var general: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch Pastewell at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                Text("The Dock icon is required for standard window minimization.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Show menu-bar item", isOn: $settings.showMenuBarItem)
            }

            Section("History") {
                Stepper("Keep \(settings.historyLimit) unpinned items", value: $settings.historyLimit, in: 25...1000, step: 25)
            }

            Section("Shortcut") {
                Picker("Open Pastewell", selection: $settings.hotKeyPreset) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
            }

            if let error = settings.settingsError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    private var behavior: some View {
        Form {
            Section("Selecting an item") {
                Toggle("Paste immediately", isOn: $settings.autoPaste)
                Text(settings.autoPaste ? "Selection returns to the previous app and pastes." : "Selection only restores the clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Keep window open after selection", isOn: $settings.keepWindowOpen)
                Toggle("Clear search after selection", isOn: $settings.clearSearchAfterPaste)
            }

            Section("Window") {
                Toggle("Float above other windows", isOn: $settings.floatAboveWindows)
                Toggle("Remember window position and size", isOn: $settings.rememberWindowPosition)
            }
        }
        .formStyle(.grouped)
    }

    private var appearance: some View {
        Form {
            Section("Colour") {
                Picker("Accent", selection: $settings.accentPreset) {
                    ForEach(AccentPreset.allCases) { preset in
                        Label {
                            Text(preset.title)
                        } icon: {
                            Circle().fill(preset.color)
                        }
                        .tag(preset)
                    }
                }
                Picker("Appearance", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("History rows") {
                Picker("Spacing", selection: $settings.rowDensity) {
                    ForEach(RowDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                Stepper("Preview lines: \(settings.previewLines)", value: $settings.previewLines, in: 1...5)
                Toggle("Show timestamps", isOn: $settings.showTimestamps)
            }

            Button("Restore Appearance Defaults") {
                settings.accentPreset = .violet
                settings.appearanceMode = .system
                settings.rowDensity = .comfortable
                settings.previewLines = 2
                settings.showTimestamps = true
            }
        }
        .formStyle(.grouped)
    }

    private var privacy: some View {
        Form {
            Section("Local storage") {
                Label("Clipboard history stays on this Mac.", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(settings.accentPreset.color)
                Text("~/Library/Application Support/Pastewell/history.json")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Toggle("Delete all history when Pastewell quits", isOn: $settings.clearHistoryOnQuit)
            }

            Section("Recording") {
                Toggle("Pause clipboard recording", isOn: $store.isPaused)
                Text("Concealed and transient clipboard types are always ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                Label(
                    AccessibilityPermission.isGranted ? "Accessibility granted" : "Accessibility required for automatic paste",
                    systemImage: AccessibilityPermission.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(AccessibilityPermission.isGranted ? .green : .orange)
            }
        }
        .formStyle(.grouped)
    }
}
