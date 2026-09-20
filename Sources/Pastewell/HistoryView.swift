import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var settings: AppSettings
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onShowSettings: () -> Void

    @State private var query = ""
    @State private var selectedEntryID: UUID?
    @State private var editingEntry: ClipboardEntry?
    @FocusState private var searchIsFocused: Bool

    private var matchingEntries: [ClipboardEntry] {
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return store.orderedEntries }
        return store.orderedEntries.filter { entry in
            tokens.allSatisfy { token in
                entry.text.localizedCaseInsensitiveContains(token)
                    || entry.sourceAppName?.localizedCaseInsensitiveContains(token) == true
            }
        }
    }

    private var selectedEntry: ClipboardEntry? {
        matchingEntries.first(where: { $0.id == selectedEntryID })
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(settings.accentPreset.color.gradient)
                .frame(height: 4)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(settings.accentPreset.color)
                TextField("Search clipboard history", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchIsFocused)
                    .onSubmit {
                        if let entry = selectedEntry ?? matchingEntries.first {
                            restore(entry)
                        }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            if matchingEntries.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "No Clipboard History" : "No Matches",
                    systemImage: "clipboard",
                    description: Text(query.isEmpty ? "Copy some text to get started." : "Try another search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    List(matchingEntries, selection: $selectedEntryID) { entry in
                        ClipboardRow(
                            entry: entry,
                            settings: settings,
                            isQueued: store.isQueued(entry),
                            restore: { restore(entry) },
                            edit: { editingEntry = entry },
                            toggleQueue: { store.toggleQueue(entry) },
                            togglePin: { store.togglePin(entry) },
                            delete: { store.delete(entry) }
                        )
                        .id(entry.id)
                        .tag(entry.id)
                    }
                    .listStyle(.plain)
                    .onChange(of: store.entries.first?.id) { _, newestID in
                        guard query.isEmpty, let newestID else { return }
                        selectedEntryID = newestID
                        withAnimation(.easeOut(duration: 0.2)) {
                            scrollProxy.scrollTo(newestID, anchor: .top)
                        }
                    }
                }
            }

            Divider()

            if !store.pasteQueue.isEmpty {
                QueueBar(
                    count: store.pasteQueue.count,
                    accent: settings.accentPreset.color,
                    pasteNext: pasteNextQueuedItem,
                    clear: store.clearQueue
                )
                Divider()
            }

            if store.needsAccessibilityPermission {
                Label(
                    "Allow Pastewell in System Settings → Privacy & Security → Accessibility, then select the item again.",
                    systemImage: "hand.raised.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            HStack {
                Button(store.isPaused ? "Resume" : "Pause") {
                    store.isPaused.toggle()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(store.isPaused ? .orange : settings.accentPreset.color)

                Spacer()

                Text(settings.autoPaste ? "Return to paste • Esc to close" : "Return to copy • Esc to close")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    store.clear()
                }
                .buttonStyle(.borderless)
                .disabled(store.entries.allSatisfy(\.isPinned))

                Button(action: onShowSettings) {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(settings.accentPreset.color)
                .help("Settings (⌘,)")
            }
            .padding(10)
        }
        .frame(minWidth: 320, minHeight: 240)
        .tint(settings.accentPreset.color)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .onAppear {
            query = ""
            selectedEntryID = matchingEntries.first?.id
            searchIsFocused = true
        }
        .onChange(of: query) { _, _ in
            keepSelectionInVisibleResults()
        }
        .onChange(of: store.entries) { _, _ in
            keepSelectionInVisibleResults()
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                moveSelection(by: -1)
            case .down:
                moveSelection(by: 1)
            default:
                break
            }
        }
        .onExitCommand(perform: onDismiss)
        .sheet(item: $editingEntry) { entry in
            EditClipView(entry: entry, accent: settings.accentPreset.color) { text in
                store.update(entry, text: text)
            }
        }
    }

    private func restore(_ entry: ClipboardEntry) {
        store.restore(entry)
        if settings.clearSearchAfterPaste {
            query = ""
        }
        onRestore()
    }

    private func pasteNextQueuedItem() {
        guard store.restoreNextQueuedEntry() else { return }
        onRestore()
    }

    private func keepSelectionInVisibleResults() {
        guard !matchingEntries.isEmpty else {
            selectedEntryID = nil
            return
        }
        if !matchingEntries.contains(where: { $0.id == selectedEntryID }) {
            selectedEntryID = matchingEntries.first?.id
        }
    }

    private func moveSelection(by offset: Int) {
        guard !matchingEntries.isEmpty else { return }
        guard let selectedEntryID,
              let currentIndex = matchingEntries.firstIndex(where: { $0.id == selectedEntryID }) else {
            self.selectedEntryID = matchingEntries.first?.id
            return
        }
        let nextIndex = min(max(currentIndex + offset, 0), matchingEntries.count - 1)
        self.selectedEntryID = matchingEntries[nextIndex].id
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    @ObservedObject var settings: AppSettings
    let isQueued: Bool
    let restore: () -> Void
    let edit: () -> Void
    let toggleQueue: () -> Void
    let togglePin: () -> Void
    let delete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            SourceAppIcon(bundleIdentifier: entry.sourceBundleIdentifier)

            Button(action: restore) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.text.replacingOccurrences(of: "\n", with: " "))
                        .lineLimit(settings.previewLines)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 5) {
                        if let sourceAppName = entry.sourceAppName, !sourceAppName.isEmpty {
                            Text(sourceAppName)
                        }
                        if entry.sourceAppName != nil && settings.showTimestamps {
                            Text("•")
                        }
                        if settings.showTimestamps {
                            Text(entry.copiedAt, style: .relative)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: toggleQueue) {
                Image(systemName: isQueued ? "checkmark.circle.fill" : "text.badge.plus")
                    .foregroundStyle(isQueued ? settings.accentPreset.color : .secondary)
            }
            .buttonStyle(.plain)
            .help(isQueued ? "Remove from paste queue" : "Add to paste queue")

            Button(action: edit) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit clip")

            Button(action: togglePin) {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(entry.isPinned ? Color(red: 0.961, green: 0.647, blue: 0.141) : .secondary)
            }
            .buttonStyle(.plain)
            .help(entry.isPinned ? "Unpin" : "Pin")

            Button(action: delete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, settings.rowDensity.verticalPadding)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? settings.accentPreset.color.opacity(0.13) : .clear)
        }
        .onHover { isHovering = $0 }
    }
}

private struct SourceAppIcon: View {
    let bundleIdentifier: String?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 22, height: 22)
    }

    private var icon: NSImage? {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

private struct QueueBar: View {
    let count: Int
    let accent: Color
    let pasteNext: () -> Void
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label("\(count) in paste queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Clear", action: clear)
                .buttonStyle(.borderless)

            Button(action: pasteNext) {
                Label("Paste Next", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Paste the next queued item (⌘Return)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct EditClipView: View {
    let entry: ClipboardEntry
    let accent: Color
    let save: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(entry: ClipboardEntry, accent: Color, save: @escaping (String) -> Void) {
        self.entry = entry
        self.accent = accent
        self.save = save
        _text = State(initialValue: entry.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Clip")
                .font(.title2.bold())

            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minWidth: 420, minHeight: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                }

            HStack {
                Text("\(text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty || text == entry.text)
            }
        }
        .padding(18)
        .tint(accent)
    }
}
