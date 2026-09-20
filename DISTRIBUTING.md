# Distributing Pastewell

## Quick, free distribution

Run:

```sh
./package-release.sh
```

This creates a universal ZIP and SHA-256 checksum in `dist/`. It runs on both
Apple Silicon and Intel Macs with macOS 14 or newer.

The free build is ad-hoc signed. Because it is not notarized by Apple, after a
person tries opening it once they may need to go to **System Settings → Privacy
& Security → Security**, choose **Open Anyway**, and confirm the launch. Never
advise users to disable Gatekeeper globally.

## GitHub Releases

Pastewell follows semantic versioning:

- Patch (`0.1.1` → `0.1.2`) for fixes and small improvements.
- Minor (`0.1.1` → `0.2.0`) for backward-compatible features.
- Major (`0.x` → `1.0.0`, then `1.x` → `2.0.0`) for significant or
  incompatible changes.

### Release checklist

1. Make sure the changes are committed on `main`, pushed, and passing the
   **Build** workflow:

   ```sh
   git switch main
   git pull --ff-only
   git status
   ```

2. Update both values in `Info.plist`:

   - `CFBundleShortVersionString`: the public version, such as `0.1.2`.
   - `CFBundleVersion`: an integer that increases for every release.

3. Build and test the exact source being released:

   ```sh
   ./build-app.sh
   open Pastewell.app
   ```

4. Create the universal release archive and verify its checksum:

   ```sh
   ./package-release.sh
   cd dist
   shasum -a 256 -c Pastewell-0.1.2-macOS-universal.zip.sha256
   cd ..
   ```

5. Commit and push the version change:

   ```sh
   git add Info.plist
   git commit -m "Prepare version 0.1.2 release"
   git push origin main
   ```

6. After the **Build** workflow is green, create and push an annotated tag
   matching `CFBundleShortVersionString`:

```sh
git tag -a v0.1.2 -m "Pastewell 0.1.2"
git push origin v0.1.2
```

7. Open the repository's **Actions** page and confirm the **Release** workflow
   succeeded. Then verify the ZIP and checksum appear under:

   ```text
   https://github.com/Tobzzy/Pastewell/releases/latest
   ```

Pushing the tag makes GitHub build a fresh universal ZIP and checksum, generate
release notes, and publish them on the Releases page. Never reuse or move a
published version tag; increment the patch version if a release attempt needs a
fix.

## Polished distribution with Apple notarization

Normal double-click installation requires an Apple Developer Program
membership, a **Developer ID Application** certificate, hardened runtime, and
notarization.

After adding the certificate to Keychain, store notarization credentials once:

```sh
xcrun notarytool store-credentials "pastewell-notary"
```

Then create a signed, notarized release:

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="pastewell-notary" \
./notarize-release.sh
```

Do not commit certificates, passwords, API keys, or notarization credentials to
the repository.
