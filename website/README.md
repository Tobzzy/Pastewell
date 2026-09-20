# Pastewell website

This directory contains the dependency-free Pastewell product site deployed to
GitHub Pages.

## Preview locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open `http://localhost:8000`.

## Future integrations

Edit `siteConfig` in `script.js` to enable App Store and GitHub Sponsors links.
Keep an empty URL to leave the corresponding button hidden.

App Store reviews should be fetched during deployment with credentials stored
in GitHub Actions secrets. Never place an App Store Connect private key in this
directory or in client-side JavaScript.
