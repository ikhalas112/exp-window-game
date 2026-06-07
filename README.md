# Mock Window Game — Protector release demo

เกมจำลองสำหรับทดสอบ pipeline `maxgame-release` (Windows: single-exe + maxion-protector, macOS: .app → zip ผ่าน ditto)

## โครงสร้าง

```
mock-window-game/
├── release.config.json       # config สำหรับ engine (มี macos block)
├── fixtures/mock-game/       # mock binary + assets (Windows)
│   ├── game.exe              # PE fixture (gen-minimal-pe หรือ build จาก game/)
│   └── assets/
├── fixtures/mock-game-macos/ # mock .app bundle (สร้างด้วย gen-mock-app.sh)
├── game/                     # Rust mock game (build จริงบน Windows)
├── scripts/
│   ├── gen-minimal-pe.py     # สร้าง PE ขั้นต่ำ (macOS/Linux)
│   ├── gen-mock-app.sh       # สร้าง mock .app fixture (macOS)
│   ├── build-mock-game.ps1   # build game.exe จาก game/ (Windows)
│   ├── run-release-local.sh  # ทดสอบ pipeline (lane: windows หรือ macos)
│   └── run-release-local.ps1 # ทดสอบ pipeline เต็ม (Windows)
└── .github/workflows/release.yml  # uses maxgame-release-tools reusable workflow
```

## ทดสอบ local

Contributor ใช้ engine จาก `../maxgame-release-tools` (compile from source + `.env`):

### macOS / Linux (mock-build + manifest, windows lane)

```bash
cd apps/mock-window-game
bash scripts/run-release-local.sh v0.1.0-dev
```

### macOS lane (.app → single zip ผ่าน ditto)

```bash
cd apps/mock-window-game
bash scripts/run-release-local.sh v0.1.0-dev dev macos
```

### Windows (รวม protect)

```powershell
cd apps\mock-window-game
.\scripts\run-release-local.ps1 v0.1.0-dev
```

## CI release

```bash
git tag v0.1.0-dev
git push origin v0.1.0-dev
```

Pipeline ใช้ `windows-latest` + reusable workflow จาก `maxgame-release-tools` (ดาวน์โหลด prebuilt binary — ไม่ต้อง submodule)

Optional org secret: `TOOLS_DOWNLOAD_TOKEN` (ถ้า tools repo เป็น private)
