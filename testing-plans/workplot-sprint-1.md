# Testing Plan — WorkPlot Sprint 1 (Dual-Method Exploit)

## Summary
Verify the Sprint 1 changes: CMG fallback exploit path, iOS 27-only gate, non-fatal bundle-identity diagnostics, corrected MobileGestalt keys (SiriMode, parallax), RDAR hardening (persistent backup + idempotency + canvas restore), Stock Snapshot auto-capture with Revert-to-Stock, and the Session Log viewer.

## Scope
- Branch: `feat/bad-query-rdar-sideload`, commit `512f1a3` or later.
- In scope: exploit connection flow, dashboard status UI, Siri AI apply, parallax toggle, RDAR fix/restore, backups menu, session log.
- Out of scope: PosterBoard lab, file workspace internals, wallpaper journaling (Sprint 2+).

## Test Users
Any Apple ID capable of sideloading (AltStore/Sideloadly/TrollStore). No account-specific behavior.

## Preconditions
1. Device on a verified iOS/iPadOS 27 build:
   - Developer betas: `24A5355q`, `24A5370h`, `24A5380h`, `24A5380i` (iPad), `24A5380l` (PB1), `24A5390f` (dev b4 / PB2).
2. Fresh install preferred. Note the **bundle identifier of the signed IPA** before installing (check in Sideloadly/TrollStore logs).
3. Device has finished first boot after the beta update; battery > 30%.

## Environment
- iPhone or iPad on an allowlisted 27 build.
- Build produced by CI ("Build unsigned IPA" artifact) and signed by your usual signer.

## Step-by-step Checklist

| # | Surface | Action | Expected |
|---|---------|--------|----------|
| 1 | Install | Sign & install the new IPA | Installs without error even if the signer rewrote the bundle id |
| 2 | Status dashboard | Launch app | OS Build row shows your build; Method row shows `—`; Status = Locked |
| 3 | Status dashboard | Wait for auto-connect (or trigger connect) | Method row shows `bad_query` **or** `cmg`; Status = Active; log line "connect ok via …" |
| 4 | Status dashboard | If Method shows `cmg` | An informational signing hint appears explaining the signer rewrote the bundle id |
| 5 | More → Session Log | Open viewer | Timestamped lines exist (session start, connect result); Copy works; Clear empties it |
| 6 | Backups menu | Open ellipsis menu | "Revert to Stock Snapshot" present but disabled until snapshot exists |
| 7 | Gestalt tweaks | Apply any harmless tweak (e.g. Boot Chime) then respring | Change takes effect; plist saved; backup list gains a timestamped entry |
| 8 | Siri AI | Apply Siri AI patch → respring → **restart device** | After reboot Siri shows Join Waitlist (expected); no crash |
| 9 | Display tweaks | Toggle Disable Parallax, save, respring | Parallax disabled — proves key `mmu76v66k1dAtghToInT8g` is honored |
| 10 | Backups menu | Revert to Stock Snapshot → confirm | Plist returns to pristine state; respring prompt appears |
| 11 | RDAR fix | Run Fix rdar blur from dashboard | First run applies; second run reports already-fixed without writing |
| 12 | RDAR restore | Use Restore Original Wallpaper Canvas (backups menu) | Original canvas bytes restored via persistent backup |
| 13 | Files app | Check `On My iPhone → WorkPlot → MobileGestalt Backups` | Contains `Stock Snapshot.plist` + timestamped backups |

## Edge Cases
- **Signer rewrote bundle id** (`com.work.plot` style): connect must still succeed — via `cmg` method. This was the primary failure before Sprint 1.
- **Unsupported build** (e.g. iOS 26): app refuses to connect with the 27-only message; no partial writes.
- **Airplane mode / offline**: exploit paths are local; nothing should require network.
- **Second connect**: repeated connects are idempotent; no duplicate Stock Snapshots.

## Regression Checks
- CacheData Siri AI marker patch still produces exactly one character flip.
- Backup-before-every-write still enforced (timestamped backup appears on each save).
- Failed write still rolls back to original bytes (verified rollback intact).

## Sign-off
- [ ] All steps pass on device
- [ ] Method row shows expected exploit for this install
- [ ] Revert-to-Stock restores cleanly
Tester: ____________ Date: ________
