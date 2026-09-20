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

The release workflow runs when a version tag is pushed:

```sh
git tag v0.1.0
git push origin v0.1.0
```

GitHub then builds the universal ZIP and attaches it to a new Release. Keep the
tag and `CFBundleShortVersionString` in `Info.plist` aligned.

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
