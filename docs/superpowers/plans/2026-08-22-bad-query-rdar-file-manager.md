# Bad Query RDAR Sideload and Safe File Manager Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the RDAR status-bar patch report sideload identity failures clearly, write the real preferences path transactionally, and extend the existing file workspace with safe create/copy/move/import/share/search operations.

**Architecture:** Keep all privileged access on the existing `bad_query` lease path. Add identity/stage diagnostics at the Objective-C bridge, make `InodeWriter` own backup/verification/rollback once for every caller, and expose only ordinary file operations through the existing `FileBrowserService` and `FilePatchWorkspaceView`. Do not port kernel exploits, root terminals, ownership changes, package installation, or network services from reference IPAs.

**Tech Stack:** SwiftUI, Foundation, Objective-C/C bridge, Xcode project settings, PowerShell checks, GitHub Actions.

---

### Task 1: Prove and fix sideload identity diagnostics

**Files:**
- Modify: `WorkPlot/WorkPlot.xcodeproj/project.pbxproj`
- Modify: `WorkPlot/Exploit/BadQueryBridge.h`
- Modify: `WorkPlot/Exploit/BadQueryBridge.m`
- Modify: `WorkPlot/Managers/ExploitManager.swift`
- Test: `Support/check-feature.ps1`

1. Add a failing check that validates the built product expects `com.apple.mobile.MobileHouseArrest` and that the runtime access check returns a concrete identity or bridge-stage error.
2. Run `rtk powershell -ExecutionPolicy Bypass -File Support/check-feature.ps1` and confirm the new assertion fails because the target still uses `com.workplot.app` and the bridge has no identity preflight.
3. Set both build configurations to the MobileHouseArrest identifier.
4. Add one bridge preflight that rejects a rewritten runtime bundle identifier before calling ContainerManager and names the missing/rejected stage in the returned error.
5. Surface that error through the existing `ExploitManager.checkSystemPathAccess()` status path.
6. Re-run the feature check and commit only these files with `fix: diagnose bad query sideload identity`.

### Task 2: Make RDAR writes transactional on the real path

**Files:**
- Modify: `WorkPlot/Managers/InodeWriter.swift`
- Modify: `WorkPlot/Managers/RDARFix.swift`
- Create: `Support/InodeWriterCheck.swift`
- Modify: `.github/workflows/main.yml`

1. Add an executable Swift check that writes replacement bytes to an existing temporary file, verifies the inode is preserved, and verifies the original bytes are restored when post-write validation rejects the result.
2. Add the check to the macOS workflow and run its compile command once on CI before implementation; confirm it fails because the transactional API does not exist.
3. Add the minimum `InodeWriter` API that snapshots original bytes, writes in place, validates the final bytes, and attempts rollback before throwing.
4. Change `RDARFix` to lease `/var/preferences/com.apple.iomobilegraphicsfamily.plist` while reading/writing `/private/var/preferences/com.apple.iomobilegraphicsfamily.plist` through the transactional writer.
5. Run the check and unsigned archive in CI, then commit with `fix: make RDAR writes transactional`.

### Task 3: Extend the existing safe file workspace

**Files:**
- Create: `WorkPlot/Managers/SafeFileOperations.swift`
- Modify: `WorkPlot/Managers/FileBrowserService.swift`
- Modify: `WorkPlot/UI/FilePatchWorkspaceView.swift`
- Create: `Support/FileBrowserServiceCheck.swift`
- Modify: `.github/workflows/main.yml`

1. Add a Foundation-only executable check using a temporary directory. It must exercise create file/folder, copy, move, import, export, and invalid-name rejection through a concrete `SafeFileOperations` helper.
2. Add the check to CI and confirm it fails because the operations are missing.
3. Implement the smallest shared path/name validation and Foundation operations in `SafeFileOperations`, then make `FileBrowserService` wrap them with the existing bad-query lease for protected paths.
4. Wire native SwiftUI controls into `FilePatchWorkspaceView`: `.searchable`, toolbar create/import/paste actions, and row context actions for copy/move/share. Preserve the existing text/plist editor.
5. Run the service check and unsigned archive, then commit with `feat: expand safe file workspace`.

### Task 4: Document, verify, and open the PR

**Files:**
- Modify: `docs/DEVLOG-FE.md`
- Include: `docs/superpowers/specs/2026-08-22-bad-query-rdar-sideload-design.md`
- Include: `docs/superpowers/plans/2026-08-22-bad-query-rdar-file-manager.md`

1. Append an FE devlog entry covering the changed files, why bundle/runtime diagnostics and transactional writes are centralized, and the deferred root-only/ZIP feature debt.
2. Run local PowerShell checks, verify only intended paths are staged, and confirm `README.md`, `.omo/`, `skill-observations/`, and `graphify-out/` are excluded.
3. Push `feat/bad-query-rdar-sideload`, wait for the GitHub Actions checks, and do not claim on-device success; record that a supported-device sideload remains required.
4. Create a PR against `gievano/apps-adnan-gievano:main` with an English title/body and verified test evidence.
