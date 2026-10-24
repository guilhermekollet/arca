<div align="center">
  <img src="Resources/icon-1024.png" alt="Arca" width="96" height="96">

  <h1>Arca</h1>

  <p>Everything you need to pick a project up again — context, environment variables, accesses and
  passwords — encrypted on your Mac and opened with Touch ID.</p>

  <p>
    <a href="https://github.com/guilhermekollet/arca/actions/workflows/ci.yml"><img src="https://github.com/guilhermekollet/arca/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-b8a4f8" alt="MIT license"></a>
    <img src="https://img.shields.io/badge/macOS-26%2B-0d0d0d" alt="macOS 26+">
    <img src="https://img.shields.io/badge/Swift-6.2-F05138" alt="Swift 6.2">
  </p>
</div>

Months after you last touched a project, a bug report arrives. Where is the code? How do you run
it? Which `.env` did production use? What was the database password, and why was it built this
way? Arca keeps those answers together, one project at a time, in a vault that never leaves your
Mac.

> **Language note:** the app's interface follows your Mac's language: Portuguese (Brazil), English or
> Spanish, and English on a Mac set to any other language. Code, comments and docs are in English.

## Contents

- [Features](#features)
- [How the vault is protected](#how-the-vault-is-protected)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Development](#development)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## Features

**Projects**
- A project per thing you maintain, with a symbol, a one-line summary, tags and a status:
  active, in maintenance, paused or archived.
- **Context**: free Markdown text for how to run it, how it's deployed, where things are, the
  decisions taken, gotchas and who to ask. An outline gets you started.
- The project's folder on your Mac, opened in Finder or Terminal with one click.
- **Links**: repository, production, dashboards, docs.

**Environment variables**
- One set per environment (development, staging, production…), edited in place.
- Import a `.env` file or paste one; values already there are updated, new keys added, and names
  like `*_TOKEN`, `*_SECRET` or `DATABASE_URL` are marked secret on the way in.
- Copy a whole set as `.env`, or save it as a file next to the code.

**Accesses**
- Dashboards, databases, servers, API keys and email accounts, with username, password, address and
  notes.
- A password generator without look-alike characters or quotes that break shells and `.env` files.

**Everyday details**
- Search everything from the sidebar: names, context, tags, links, variable names and usernames.
  Secret values are never searched.
- The menu bar icon finds an access or a variable across all projects and copies it, without
  opening the main window (try "aurora prod database").
- Secrets are copied as concealed, so clipboard managers skip them, and cleared after 30 seconds.
- The vault locks itself after 15 minutes without using the Mac, and when it sleeps or the screen
  locks (both adjustable in **Ajustes**).

## How the vault is protected

| Piece | Where it lives |
| --- | --- |
| Projects, variables, accesses | One file, `~/Library/Application Support/Arca/vault.arca`, encrypted with ChaCha20-Poly1305 under a random 256-bit vault key. |
| The vault key | Inside the same file, sealed for the device key (P256 key agreement + HKDF-SHA256). |
| The device key | Created inside the Mac's **Secure Enclave**, which never lets it out. Using it requires Touch ID or the Mac's password. |
| The device key's handle | Your login Keychain. It is encrypted by the Secure Enclave and useless on any other Mac. |
| Backups | `Backups/` next to the vault: the vault as it was before each session's first change, the 20 most recent, encrypted the same way. |

There is no master password, no account and no server: nothing is sent anywhere. The flip side is
that **the vault only opens on the Mac that created it**. If that Mac is lost or its Keychain
reset, the vault can't be recovered. An encrypted export you can open elsewhere is on the roadmap;
until then, keep what you can't lose somewhere else too.

See [SECURITY.md](SECURITY.md) for what this protects against, and what it doesn't.

## Requirements

- macOS 26 (Tahoe) or later on a Mac with a Secure Enclave (Apple silicon, or Intel with a T2 chip).
- To build from source: Swift 6.2 or later — Xcode 26, or the matching Command Line Tools.

## Getting started

```bash
git clone https://github.com/guilhermekollet/arca.git
cd arca
scripts/create-signing-cert.sh   # recommended, see "Signing" below
./build.sh
open build/Arca.app
```

On first launch, click **Criar cofre** (Create vault). From then on Arca opens with Touch ID. It
lives in the Dock and in the menu bar; closing the window keeps it in the menu bar.

### Signing

The Keychain remembers which app may read the device key's handle by its signature. An ad hoc
signature changes on every build, so macOS would ask again each time.
`scripts/create-signing-cert.sh` creates a self-signed certificate in your login keychain, which
`build.sh` uses automatically; choose **Always Allow** the first time macOS asks. To use another
identity, set `ARCA_SIGNING_IDENTITY`.

## Development

```bash
swift build                     # debug build
scripts/test.sh                 # tests (works with Xcode or with only the Command Line Tools)
./build.sh                      # release build and app bundle
open build/Arca.app --args --sample   # a made-up vault in memory: no Touch ID, nothing saved
build/Arca.app/Contents/MacOS/Arca --snapshot /tmp/arca-screens   # draw every screen to PNG and quit
ARCA_VAULT_DIR=/tmp/arca-dev open build/Arca.app   # a separate vault, to try things safely
```

`--sample` is the way to work on the interface without touching your vault, and `--snapshot` draws
each screen with it (main window per tab, lock screens, settings, menu bar panel, access editor)
without Touch ID or permission to record the screen. The translucent sidebar and toolbar come out
blank in those drawings; everything else is as on screen.

Arca shares Mara AI's design: near-black, off-white and lavender as the only accent, the system
font, pill-shaped buttons, icon tabs and a dot-matrix mark. The tokens and shared controls are in
`Sources/Arca/Theme.swift`.

## Project layout

```
Sources/Arca/
  ArcaApp.swift            App entry point, main window, menu bar item, commands
  Vault.swift              The vault while the app runs: unlock, lock, saving, backups, auto-lock
  VaultFile.swift          The file format and its encryption
  DeviceKey.swift          The Secure Enclave key and its handle in the Keychain
  Models.swift             Projects, environments, variables, accesses, search
  DotEnv.swift             Reading and writing .env files
  PasswordGenerator.swift  Random passwords
  Clipboard.swift          Concealed copies that clear themselves
  RootView.swift           Lock screen, sidebar and the split view
  ProjectView.swift        A project's header, context and links
  VariablesTab.swift       Environments and their variables, import and export
  CredentialsTab.swift     Accesses, their editor and the password generator
  MenuBarPanel.swift       Quick search from the menu bar
  SettingsView.swift       Settings
  Theme.swift              Colors, the dot-matrix mark and the shared controls (pills, cards, tabs)
  SampleVault.swift        The made-up vault behind --sample
  Snapshot.swift           --snapshot: draws every screen to PNG
  Localization.swift       Picks the interface language; translations live in Resources/*.lproj
Tests/ArcaTests/           Swift Testing suite
scripts/                   Icon generation, signing, test runner, commit helper
```

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) to get set up, and the
[Code of Conduct](CODE_OF_CONDUCT.md). Found a security issue? See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © Guilherme Kollet
