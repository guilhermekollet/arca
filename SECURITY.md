# Security Policy

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's **Report a vulnerability** button in the
repository's Security tab to send a private report, and include steps to reproduce.

## Threat model

Keys keeps passwords, API keys and environment variables, so this section says plainly what it
defends against.

**Protected**

- Someone who gets the vault file or a backup — from a backup drive, a cloud sync folder, another
  user account or a stolen disk image — without this Mac. The vault key is sealed for a key that
  only this Mac's Secure Enclave can use.
- Someone using this Mac while the vault is locked. Opening it takes Touch ID or the Mac's
  password, enforced by the Secure Enclave, not just by the app.
- Someone who gets an exported backup but not its password. The contents are sealed under a key
  derived from the password; the header (format, rounds, salt, date) is authenticated too, so
  lowering the round count or swapping the salt makes the file refuse to open.
- Tampering. Both seals authenticate the file's header; a changed byte, or contents and keys mixed
  from different vaults, is refused as damaged.
- Copied secrets lingering. They are marked concealed and transient for clipboard managers and
  Universal Clipboard, and cleared after 30 seconds by default.

**Not protected**

- Malware running as your user while the vault is open: the contents are in the app's memory.
  The vault stays open for the unlock time you choose (2 hours by default), so a shorter one
  narrows that window.
- Someone who knows your Mac's password and has your Mac.
- Losing the Mac or resetting its Keychain without an exported backup: the vault can't be opened
  anywhere else. This is the price of having no master password; an exported backup is the way
  back.
- A weak backup password. Exported backups are as strong as their password: PBKDF2 with a million
  rounds makes each guess slow, but it isn't memory-hard, so a short or common password can still
  be guessed by someone who has the file. The app asks for at least 10 characters; a long phrase
  is much better.
- `.env` files you export: they are plain text by design, because that is what tools read.

## What matters most here

- Any way to read the vault's contents without the Secure Enclave key and user presence.
- Secrets reaching disk unencrypted (logs, caches, crash reports, temporary files), except files
  the person exports on purpose.
- Secret values appearing in search indexes, Spotlight, or anything sent off the Mac. Keys sends
  nothing anywhere; any network request is a bug.
- The vault being saved in a way that loses data (a partial write, a backup not taken).
- An import that loses data: merging must never delete a project, and a vault this Mac can't
  open must be set aside, not overwritten.
