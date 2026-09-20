# Pastewell

Pastewell is a tiny, local-only clipboard history app for macOS 14 and newer.

It is open-source software released under the [MIT License](LICENSE).

Website: [tobzzy.github.io/Pastewell](https://tobzzy.github.io/Pastewell/)

## Download

Download the latest universal macOS ZIP from the repository's **Releases**
page. The free community build is ad-hoc signed. After trying to open it once,
go to **System Settings → Privacy & Security**, scroll to **Security**, and
choose **Open Anyway**. macOS remembers the exception after you confirm it.

## Features

- Text clipboard history stored only on this Mac
- Multi-word search across clip text and source-app names
- Keyboard selection with Up/Down and Return
- Pin, edit, delete, clear, and pause
- Source-app names and icons for newly copied clips
- A paste queue for filling several fields in sequence
- Opens with Command-Shift-V
- Pastes the selected entry into the most recently active app
- Movable, resizable, and minimizable history window
- Stays visible between pastes and hides with Escape
- Ink Violet visual theme with six alternative accent presets
- Settings for paste behavior, window behavior, history size, appearance, startup, and privacy
- Keeps the 100 most recent unpinned entries
- Ignores common concealed and transient clipboard types
- No network calls, accounts, analytics, or third-party dependencies

## Build and run

1. Install Xcode from Apple.
2. If required, review and accept its license in Terminal:

   ```sh
   sudo xcodebuild -license
   ```

3. Build the app. Pastewell's script invokes the Swift compiler directly, so it
   also works around installations where `xcodebuild` cannot load its optional
   device-support frameworks:

   ```sh
   ./build-app.sh
   ```

4. Launch it:

   ```sh
   open Pastewell.app
   ```

Pastewell appears as a clipboard icon in the menu bar. Click it or press
Command-Shift-V, then choose an entry to paste it immediately. On the first
automatic paste, macOS asks you to allow Pastewell under System Settings >
Privacy & Security > Accessibility.

Open Pastewell settings with the gear button or Command-comma.

Use the queue button beside any clip to add it to the paste queue. **Paste
Next** pastes clips in the order you added them; Command-Return does the same
while Pastewell is open.

Clipboard history is stored at:

```text
~/Library/Application Support/Pastewell/history.json
```

Right-click the menu-bar icon to pause, clear history, or quit.

## Create a downloadable build

```sh
./package-release.sh
```

The universal ZIP for Apple Silicon and Intel Macs is written to `dist/`.
Instructions for GitHub Releases and optional Apple notarization are in
[DISTRIBUTING.md](DISTRIBUTING.md).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and report
security issues according to [SECURITY.md](SECURITY.md).

The product website lives in [`website/`](website). See its README for local
preview and future App Store, review, and sponsorship integration notes.
