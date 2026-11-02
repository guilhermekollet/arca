# Contributing to Chaves

Thanks for helping! This guide covers how to set up the project, what we expect from a change and
how to get it merged.

## Setup

1. macOS 26 or later with Swift 6.2+ (Xcode 26, or the Command Line Tools 26.1+), on a Mac with a
   Secure Enclave.
2. Clone the repository and build once: `./build.sh`.
3. Optional but recommended: `scripts/create-signing-cert.sh`, so the Keychain keeps letting your
   builds read the device key (see the README).
4. Run the tests: `scripts/test.sh`.

To work on the interface without touching your own vault, run `open build/Chaves.app --args --sample`
(a made-up vault in memory, nothing saved) or point the app at another folder with
`CHAVES_VAULT_DIR`.

## Making a change

- **Open an issue first** for anything bigger than a small fix, so we can agree on the approach.
- **Keep pull requests focused**: one change per PR, with a description of what and why.
- **Match the surrounding code**: SwiftUI views, a `@MainActor` vault, small helpers, and comments
  that explain *why*, not *what*. Code and comments are in English. The app's UI text is written
  in Brazilian Portuguese inside `localized("…")`, which is also its key: add the English and
  Spanish versions to `Sources/Chaves/Resources/en.lproj` and `es.lproj` (a test checks for it).
- **Add or update tests** for logic you touch. The suite uses Swift Testing (`import Testing`).
  If a helper needs Foundation or CryptoKit, put it in `Tests/ChavesTests/Fixtures.swift`: with only
  the Command Line Tools installed, a file that imports both `Testing` and `Foundation` does not
  compile.
- **Never break old vaults**: a new field needs a default in its `init(from:)` (see `Models.swift`),
  and a change to the file format needs a new `VaultFile.currentVersion` and a way to read the old
  one.
- **Keep the look**: Chaves shares Mara AI's design. Use the colors and controls in `Theme.swift`
  (`PillButtonStyle`, `IconButton`, `Card`, `CapsuleTabs`) rather than new ones, and keep the
  behavior a Mac user expects: menu commands with their usual shortcuts, help tags on icon
  buttons, Delete to remove, confirmation before anything is lost.
- **Check it builds and the tests pass**: `swift build` and `scripts/test.sh`. For UI changes,
  include the screens drawn by `build/Chaves.app/Contents/MacOS/Chaves --snapshot <folder>`.
- **Security is the feature**: nothing leaves the Mac, and secrets never reach disk unencrypted
  unless the person exports them. Call out any change that touches the vault, the keys or the
  clipboard.

## Commit messages

Use the [Conventional Commits](https://www.conventionalcommits.org) style, in English, for example
`feat(variables): import from docker compose files` or `fix(vault): keep the backup on save`.
No co-author or "generated with" trailers.

`scripts/ship.sh` does the whole round and checks the convention at each step:

```bash
scripts/ship.sh setup                                   # once: check every commit message
scripts/ship.sh branch fix/clipboard-clear
git add -p
scripts/ship.sh commit "fix(clipboard): clear only what chaves copied" body.txt
scripts/ship.sh push
scripts/ship.sh pr                                      # title and description from the commit
scripts/ship.sh merge 42                                # maintainers: squash once checks pass
```

## Reporting bugs

Use the bug report template. Never paste real secrets, variable values or vault files into an
issue.
