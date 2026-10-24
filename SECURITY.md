# Security Policy

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's **Report a vulnerability** button in the
repository's Security tab to send a private report, and include steps to reproduce.

## Threat model

Arca keeps passwords, API keys and environment variables, so this section says plainly what it
defends against.

**Protected**

- Someone who gets the vault file or a backup — from a backup drive, a cloud sync folder, another
  user account or a stolen disk image — without this Mac. The vault key is sealed for a key that
  only this Mac's Secure Enclave can use.
- Someone using this Mac while the vault is locked. Opening it takes Touch ID or the Mac's
  password, enforced by the Secure Enclave, not just by the app.
- Tampering. Both seals authenticate the file's header; a changed byte, or contents and keys mixed
  from different vaults, is refused as damaged.
- Copied secrets lingering. They are marked concealed and transient for clipboard managers and
  Universal Clipboard, and cleared after 30 seconds by default.

**Not protected**

- Malware running as your user while the vault is open: the contents are in the app's memory.
- Someone who knows your Mac's password and has your Mac.
- Losing the Mac or resetting its Keychain: the vault can't be opened anywhere else. This is the
  price of having no master password.
- `.env` files you export: they are plain text by design, because that is what tools read.

## What matters most here

- Any way to read the vault's contents without the Secure Enclave key and user presence.
- Secrets reaching disk unencrypted (logs, caches, crash reports, temporary files), except files
  the person exports on purpose.
- Secret values appearing in search indexes, Spotlight, or anything sent off the Mac. Arca sends
  nothing anywhere; any network request is a bug.
- The vault being saved in a way that loses data (a partial write, a backup not taken).
