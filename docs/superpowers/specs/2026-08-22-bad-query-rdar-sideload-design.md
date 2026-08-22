# Bad Query RDAR Sideload Design

## Goal

Make WorkPlot report and use its existing `bad_query` access path reliably in a sideloaded build, then make RDAR repair transactional and observable on a supported physical device.

Success means:

- the installed app reports its effective bundle identifier and signing compatibility;
- access failures identify the exact failed stage instead of a generic ContainerManager error;
- RDAR reads, backs up, updates, flushes, and verifies the intended plist through one scoped lease;
- a failed write restores the original bytes;
- the UI claims success only after byte-for-byte verification;
- CI builds the unsigned IPA, followed by an on-device sideload test.

## Evidence and Working Hypothesis

The supplied 3105 and FilzaSlop IPAs both declare `com.apple.mobile.MobileHouseArrest`, while WorkPlot currently declares `com.workplot.app`. The 3105 binary also contains an explicit host-bundle check and states that its broad filesystem path depends on separate kernel and sandbox-escape stages.

The first hypothesis is that WorkPlot's generic bundle identity prevents the ContainerManager query from producing a usable token after sideloading. This remains a hypothesis until an installed build reports its effective identity and completes a read/write probe. The design therefore changes the intended identity and adds stage-specific evidence in the same patch.

## Scope

This phase includes:

- sideload identity alignment with `com.apple.mobile.MobileHouseArrest`;
- diagnostics for library loading, required symbols, query creation, daemon result, token copy, token consumption, and final file probe;
- reuse of the existing `BadQueryLeaseScope` and `InodeWriter` paths;
- canonical `/var` query path paired with `/private/var` file access where appropriate;
- transactional RDAR backup, write, rollback, and verification;
- a small deterministic check plus CI build verification;
- user-visible status suitable for an on-device feedback loop.

This phase excludes:

- kernel exploits or new sandbox-bypass techniques;
- arbitrary root filesystem access;
- terminal execution, package installation, ownership or permission mutation;
- wholesale copying of code or assets from either reference IPA;
- the larger 3105/Filza feature-parity project.

## Architecture

### App identity

Both build configurations use `com.apple.mobile.MobileHouseArrest` as the intended bundle identifier. Runtime diagnostics compare `Bundle.main.bundleIdentifier` with that value because a sideloading tool may rewrite it. A mismatch is reported as an actionable compatibility failure before ContainerManager is queried.

### Access diagnostics

`BadQueryBridge` remains the single Objective-C lease object exposed to Swift. Its error output becomes stage-specific and includes the effective bundle identifier without exposing sandbox tokens. Availability checks distinguish a failed `dlopen` from missing symbols.

The existing C implementation remains available to existing callers, but this phase does not add a third query implementation or a new abstraction. Any shared constants needed by both implementations are consolidated only where duplication directly risks behavioral drift.

### RDAR transaction

`RDARFix` uses two explicit paths:

- lease target: `/var/preferences/com.apple.iomobilegraphicsfamily.plist`;
- file target: `/private/var/preferences/com.apple.iomobilegraphicsfamily.plist`.

Within one lease, it:

1. opens and records the original bytes;
2. parses the original property-list format;
3. changes only `canvas_width` and `canvas_height`;
4. serializes in the original format;
5. rewrites the existing inode;
6. flushes and re-reads the file;
7. restores and verifies the original bytes if writing or verification fails.

The native screen bounds remain the source for canvas dimensions. No device-specific resolution table is introduced.

### Status reporting

The Status screen shows a concise phase and failure reason. It must not mark the global sandbox state active merely because private symbols exist; the state becomes active only after the MobileGestalt read/write probe succeeds. RDAR success is separate and requires verification of its own target.

## Error Handling

- Bundle mismatch: stop before query and explain that the sideload tool rewrote the identifier.
- Unsupported OS build: preserve the existing explicit build gate.
- Missing private API or symbol: name the missing stage, not a guessed remedy.
- Query/token failure: release every acquired object and return a stage-specific error.
- Read or parse failure: do not write.
- Write or verification failure: attempt rollback while the descriptor and lease are still valid.
- Rollback failure: report a high-severity error and never claim success.

No token value, user file content, or unrelated device data is logged.

## Verification

The smallest useful automated check will verify:

- both target build configurations declare the required bundle identifier;
- RDAR keeps distinct lease and canonical file paths;
- the transaction contains backup, post-write verification, and rollback handling;
- user-visible access status is based on a real probe.

CI must then build the unsigned archive. Final verification requires a supported physical device:

1. sideload while preserving the intended bundle identifier;
2. capture the displayed effective identifier and OS build;
3. request access and confirm the MobileGestalt read/write probe;
4. record the original RDAR plist hash and canvas values;
5. run RDAR Fix;
6. confirm the new bytes and values, then refresh the UI as instructed;
7. exercise a controlled failing write to verify rollback before calling the fix complete.

If the effective identifier is correct but ContainerManager still rejects the query, no additional bypass is guessed. The next iteration uses the new stage diagnostics to isolate signing, OS compatibility, or API behavior.

## Follow-up Feature Parity

After this phase works on-device, feature parity is split into separate designs:

1. safe app-container browser operations: search, tabs, create, copy, move, import, share, ZIP, and replace;
2. transactional patch projects with backups and restore;
3. cache cleaner limited to `Library/Caches` and `tmp`;
4. session logs and compatibility onboarding;
5. existing PosterBoard and MobileGestalt feature gaps.

Filza root-only functions and 3105's kernel exploit remain out of scope because they depend on privileges this bad-query-only design does not provide.
