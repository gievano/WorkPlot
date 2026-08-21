# DEVLOG-OPS

## 2026-08-22 — Rolling release `latest` dari build main

**The Change:**
- `.github/workflows/main.yml`: tambah job `latest-release` (needs build, hanya untuk push ke main, permission contents:write).
- Alur: hapus release/tag `latest` lama via `gh release delete latest --cleanup-tag -y || true`, lalu buat ulang pakai `softprops/action-gh-release@v2` dengan tag `latest`, judul "Latest Build (dev)", `prerelease: true`, `make_latest: false`, attach artifact `WorkPlot-IPA` sebagai `WorkPlot.ipa`.

**The Reasoning:**
- Konsisten gaya job `release` existing yang juga pakai softprops/action-gh-release@v2.
- `make_latest: false` WAJIB eksplisit karena softprops default-nya `true` — tanpa itu badge "Latest" akan direbut dari rilis stabil v1.0.0. Prerelease flag juga membantu menjaga badge tetap di rilis stabil.
- Link permanen user: https://github.com/gievano/work-plot2/releases/download/latest/WorkPlot.ipa

**The Tech Debt:**
- Ada jendela downtime singkat (beberapa detik) saat delete-then-create release; link bisa 404 sesaat tiap push main. Acceptable untuk use case dev.

---

## 2026-08-21 — Rilis v1.0.0

- Rilis stabil pertama v1.0.0 dibuat dari tag `v*` melalui job `release` di workflow yang sama (softprops/action-gh-release@v2, generate_release_notes aktif). Job ini menjadi pemegang badge "Latest" dan tidak boleh diganggu oleh job rolling.
