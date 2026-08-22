# DEVLOG-OPS

## 2026-08-22 — Body rolling release `latest` diubah ke English

**The Change:**
- `.github/workflows/main.yml` job `latest-release`, step `meta`: seluruh body release diganti dari Bahasa Indonesia ke English — header "Automated build from commit <sha> on main.", section "### Latest changes", "Built: <tanggal> UTC", dan warning blockquote satu baris ("⚠️ This is a dev prerelease (unsigned IPA) that gets overwritten by the next build. For stable releases, use `v*` tags."). Judul tetap "WorkPlot dev 1.0.<run_number> (<short-sha>)".

**The Reasoning:**
- Konsistensi audiens internasional; release notes adalah surface publik yang lebih tepat berbahasa Inggris. Warning dipadatkan jadi satu baris blockquote agar ringkas tanpa mengubah substansi.

**The Tech Debt:**
- Tidak ada; perubahan murni copy body.

---

## 2026-08-22 — Judul & deskripsi dinamis pada rolling release `latest`

**The Change:**
- `.github/workflows/main.yml` job `latest-release`: judul dinamis "WorkPlot dev 1.0.<run_number> (<short-sha>)", body digenerate ke file (`release-body.md` di RUNNER_TEMP) berisi header commit, 5 commit terbaru via `git log --oneline -5`, tanggal build UTC, dan catatan prerelease/stabil.
- Tambah step `actions/checkout@v4` (fetch-depth: 10) di job ini karena butuh riwayat git untuk daftar commit; metadata disiapkan di step `meta` sebelum delete-then-create release.

**The Reasoning:**
- `body_path` dipilih daripada multiline GITHUB_OUTPUT agar aman dari masalah escaping (delimiter EOF rentan bentrok).
- `git log --oneline -5` sederhana dipilih daripada diff vs tag lama — cukup sesuai spek dan tidak rawan gagal saat tag `latest` belum ada (run pertama).

**The Tech Debt:**
- GitHub melarang fork publik diubah jadi private (HTTP 422 "Public forks can't be made private"). Kalau repo harus private: detach fork via GitHub Support atau buat repo baru non-fork — perlu keputusan user.

---

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

---

## 2026-08-22 — Hapus output Graphify dari version control

**The Change:** `.gitignore` kini mengabaikan seluruh `graphify-out/`, dan output Graphify yang sebelumnya tracked dikeluarkan dari index Git tanpa menghapus salinan lokal.

**The Reasoning:** Knowledge graph adalah artefak lokal yang dapat dibuat ulang dan tidak perlu menambah ukuran maupun noise pada repository.

**The Tech Debt:** Tidak ada; artefak dapat diregenerasi lokal saat dibutuhkan.
