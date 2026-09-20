import AppKit
import Carbon.HIToolbox
import Combine
import ServiceManagement
import SwiftUI

enum AccentPreset: String, CaseIterable, Identifiable {
    case violet
    case ocean
    case mint
    case sunset
    case rose
    case system
    case monochrome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .violet: "Pastewell Violet"
        case .ocean: "Ocean Blue"
        case .mint: "Mint"
        case .sunset: "Sunset Orange"
        case .rose: "Rose"
        case .system: "System Accent"
        case .monochrome: "Monochrome"
        }
    }

    var color: Color {
        switch self {
        case .violet: Color(red: 0.486, green: 0.361, blue: 0.988)
        case .ocean: Color(red: 0.129, green: 0.494, blue: 0.957)
        case .mint: Color(red: 0.169, green: 0.714, blue: 0.659)
        case .sunset: Color(red: 0.976, green: 0.412, blue: 0.235)
        case .rose: Color(red: 0.929, green: 0.302, blue: 0.514)
        case .system: Color.accentColor
        case .monochrome: Color.primary
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum RowDensity: String, CaseIterable, Identifiable {
    case compact
    case comfortable
    case spacious

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: 2
        case .comfortable: 6
        case .spacious: 11
        }
    }
}

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case commandShiftV
    case commandShiftC
    case optionSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandShiftV: "⌘⇧V"
        case .commandShiftC: "⌘⇧C"
        case .optionSpace: "⌥Space"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .commandShiftV: UInt32(kVK_ANSI_V)
        case .commandShiftC: UInt32(kVK_ANSI_C)
        case .optionSpace: UInt32(kVK_Space)
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .commandShiftV, .commandShiftC: UInt32(cmdKey | shiftKey)
        case .optionSpace: UInt32(optionKey)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var autoPaste: Bool { didSet { save(autoPaste, "autoPaste") } }
    @Published var keepWindowOpen: Bool { didSet { save(keepWindowOpen, "keepWindowOpen") } }
    @Published var floatAboveWindows: Bool { didSet { save(floatAboveWindows, "floatAboveWindows") } }
    @Published var rememberWindowPosition: Bool { didSet { save(rememberWindowPosition, "rememberWindowPosition") } }
    @Published var clearSearchAfterPaste: Bool { didSet { save(clearSearchAfterPaste, "clearSearchAfterPaste") } }
    @Published var showDockIcon: Bool { didSet { save(showDockIcon, "showDockIcon") } }
    @Published var showMenuBarItem: Bool { didSet { save(showMenuBarItem, "showMenuBarItem") } }
    @Published var historyLimit: Int { didSet { save(historyLimit, "historyLimit") } }
    @Published var previewLines: Int { didSet { save(previewLines, "previewLines") } }
    @Published var showTimestamps: Bool { didSet { save(showTimestamps, "showTimestamps") } }
    @Published var clearHistoryOnQuit: Bool { didSet { save(clearHistoryOnQuit, "clearHistoryOnQuit") } }
    @Published var accentPreset: AccentPreset { didSet { save(accentPreset.rawValue, "accentPreset") } }
    @Published var appearanceMode: AppearanceMode { didSet { save(appearanceMode.rawValue, "appearanceMode") } }
    @Published var rowDensity: RowDensity { didSet { save(rowDensity.rawValue, "rowDensity") } }
    @Published var hotKeyPreset: HotKeyPreset { didSet { save(hotKeyPreset.rawValue, "hotKeyPreset") } }
    @Published private(set) var launchAtLogin: Bool
    @Published var settingsError: String?

    private let defaults = UserDefaults.standard

    init() {
        autoPaste = Self.bool("autoPaste", default: true)
        keepWindowOpen = Self.bool("keepWindowOpen", default: true)
        floatAboveWindows = Self.bool("floatAboveWindows", default: true)
        rememberWindowPosition = Self.bool("rememberWindowPosition", default: true)
        clearSearchAfterPaste = Self.bool("clearSearchAfterPaste", default: true)
        showDockIcon = Self.bool("showDockIcon", default: true)
        showMenuBarItem = Self.bool("showMenuBarItem", default: true)
        historyLimit = Self.integer("historyLimit", default: 100)
        previewLines = Self.integer("previewLines", default: 2)
        showTimestamps = Self.bool("showTimestamps", default: true)
        clearHistoryOnQuit = Self.bool("clearHistoryOnQuit", default: false)
        accentPreset = AccentPreset(rawValue: defaults.string(forKey: "accentPreset") ?? "") ?? .violet
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "") ?? .system
        rowDensity = RowDensity(rawValue: defaults.string(forKey: "rowDensity") ?? "") ?? .comfortable
        hotKeyPreset = HotKeyPreset(rawValue: defaults.string(forKey: "hotKeyPreset") ?? "") ?? .commandShiftV
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            settingsError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            settingsError = error.localizedDescription
        }
    }

    func reset() {
        autoPaste = true
        keepWindowOpen = true
        floatAboveWindows = true
        rememberWindowPosition = true
        clearSearchAfterPaste = true
        showDockIcon = true
        showMenuBarItem = true
        historyLimit = 100
        previewLines = 2
        showTimestamps = true
        clearHistoryOnQuit = false
        accentPreset = .violet
        appearanceMode = .system
        rowDensity = .comfortable
        hotKeyPreset = .commandShiftV
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private static func bool(_ key: String, default defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private static func integer(_ key: String, default defaultValue: Int) -> Int {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.integer(forKey: key)
    }
}
