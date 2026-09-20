import Combine
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var pasteQueue: [ClipboardEntry] = []
    @Published var needsAccessibilityPermission = false
    @Published var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: pausePreferenceKey)
        }
    }

    private let settings: AppSettings
    private let pausePreferenceKey = "isPaused"
    private lazy var monitor = ClipboardMonitor { [weak self] text, appName, bundleIdentifier in
        self?.record(text, sourceAppName: appName, sourceBundleIdentifier: bundleIdentifier)
    }

    init(settings: AppSettings) {
        self.settings = settings
        isPaused = UserDefaults.standard.bool(forKey: pausePreferenceKey)
        load()
    }

    var orderedEntries: [ClipboardEntry] {
        entries.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned
            }
            return $0.copiedAt > $1.copiedAt
        }
    }

    func startMonitoring() {
        monitor.start()
    }

    func stopMonitoring() {
        monitor.stop()
    }

    func record(
        _ text: String,
        sourceAppName: String? = nil,
        sourceBundleIdentifier: String? = nil
    ) {
        guard !isPaused else { return }

        let existing = entries.first(where: { $0.text == text })
        entries.removeAll(where: { $0.text == text })
        entries.insert(
            ClipboardEntry(
                text: text,
                isPinned: existing?.isPinned ?? false,
                sourceAppName: sourceAppName ?? existing?.sourceAppName,
                sourceBundleIdentifier: sourceBundleIdentifier ?? existing?.sourceBundleIdentifier
            ),
            at: 0
        )
        trimHistory()
        save()
    }

    func restore(_ entry: ClipboardEntry) {
        monitor.restore(entry.text)
    }

    func togglePin(_ entry: ClipboardEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].isPinned.toggle()
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll(where: { $0.id == entry.id })
        pasteQueue.removeAll(where: { $0.id == entry.id })
        save()
    }

    func update(_ entry: ClipboardEntry, text: String) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].text = text
        if let queueIndex = pasteQueue.firstIndex(where: { $0.id == entry.id }) {
            pasteQueue[queueIndex].text = text
        }
        save()
    }

    func toggleQueue(_ entry: ClipboardEntry) {
        if pasteQueue.contains(where: { $0.id == entry.id }) {
            pasteQueue.removeAll(where: { $0.id == entry.id })
        } else {
            pasteQueue.append(entry)
        }
    }

    func isQueued(_ entry: ClipboardEntry) -> Bool {
        pasteQueue.contains(where: { $0.id == entry.id })
    }

    @discardableResult
    func restoreNextQueuedEntry() -> Bool {
        guard let next = pasteQueue.first else { return false }
        pasteQueue.removeFirst()
        restore(next)
        return true
    }

    func clearQueue() {
        pasteQueue.removeAll()
    }

    func clear() {
        entries.removeAll(where: { !$0.isPinned })
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    func enforceHistoryLimit() {
        trimHistory()
        save()
    }

    private func trimHistory() {
        let unpinned = entries.filter { !$0.isPinned }
        guard unpinned.count > settings.historyLimit else { return }
        let retainedIDs = Set(unpinned.prefix(settings.historyLimit).map(\.id))
        entries.removeAll { !$0.isPinned && !retainedIDs.contains($0.id) }
    }

    private var historyURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return base.appendingPathComponent("Pastewell", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    private func load() {
        do {
            let data = try Data(contentsOf: historyURL)
            entries = try JSONDecoder().decode([ClipboardEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            let directory = historyURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            NSLog("Pastewell could not save clipboard history: %@", error.localizedDescription)
        }
    }
}
