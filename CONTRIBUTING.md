# Contributing to Pastewell

Thanks for helping improve Pastewell.

## Make a change

1. Fork the repository and clone your fork.
2. Create a focused branch from the latest `main`:

   ```sh
   git switch main
   git pull --ff-only
   git switch -c feature/short-description
   ```

3. Change the files under `Sources/Pastewell` and build on macOS 14 or newer:

   ```sh
   ./build-app.sh
   open Pastewell.app
   ```

4. Test clipboard capture, the global shortcut, keyboard navigation, paste
   queue, settings, window behavior, and Accessibility-powered pasting.
5. Commit and push the branch:

   ```sh
   git add .
   git commit -m "Describe the change"
   git push -u origin feature/short-description
   ```

6. Open a pull request explaining the problem, the behavior you changed, and
   how you tested it.

Release tags are created by the maintainer after changes reach `main`. See
[DISTRIBUTING.md](DISTRIBUTING.md) for the complete release checklist.

Please keep Pastewell local-first: avoid analytics, accounts, or network
dependencies unless the project explicitly decides to add them.
