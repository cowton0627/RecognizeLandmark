# Runbook

開發 / 維護常用操作。基本「怎麼安裝、怎麼跑」看 README;這裡放比較細、容易忘的指令。

---

## 啟用 pre-commit hook(clone 後第一件事)

repo 內 `.githooks/pre-commit` 會擋住把 Apple Developer Team ID(10 碼大寫英數)寫進 `*.pbxproj` 或 `*.xcconfig` 的 commit。Git hook 預設不會自動啟用,clone 後要設一次:

```bash
git config core.hooksPath .githooks
```

驗證:

```bash
git config core.hooksPath
# 應該輸出 .githooks
```

**為什麼需要**:Xcode 在 GUI 選 Team 時會把 Team ID 寫進 `project.pbxproj` 的 `buildSettings`(優先序高於 `Signing.xcconfig`)。沒這個 hook 就只能靠 push 前自己 grep,容易漏。

Team ID 真正該放的位置是 gitignored 的 `Config/Signing.local.xcconfig`。

要關掉 hook(不建議):`git config --unset core.hooksPath`。
單次跳過:`git commit --no-verify`(只在誤判時用)。

---

## 加新的 Swift 檔到 Xcode 專案

兩種做法:

### A. 在 Xcode 裡用 GUI(推薦給人類)
File → Add Files to "RecognizeLandmark"... → 選檔 → 確認 Target Membership 勾 `RecognizeLandmark`。

### B. 手動編 `project.pbxproj`(Claude / 沒開 Xcode 時)
要在 4 個 section 同時加(否則 SourceKit 會報 "Cannot find type" 之類的錯,build 也會缺檔):

1. `PBXBuildFile` — 加 `XXX in Sources` 的條目
2. `PBXFileReference` — 加檔案參考(只放檔名,例如 `path = MyView.swift`,parent group 已設好資料夾路徑)
3. `PBXGroup` — 加進**對應功能資料夾的 group**(`App` / `Camera` / `CaptureReview` / `Records` / `Storage` / `Services`),不要直接掛在 `RecognizeLandmark` group 下
4. `PBXSourcesBuildPhase`(`Sources` build phase 的 files 列)— 加進編譯

**UUID 規則**:檔案 UUID 照現有命名 `915D5DXX2CA6A2D000162B3B`,XX 每次 +2(一個給 buildFile,一個給 fileRef)。最近用到的對見 `git log -p RecognizeLandmark.xcodeproj/project.pbxproj`。

參考 commit(用 `git log --grep="Stage X"` 找;不寫死 SHA 是因為 SHA 在 force push 後可能失效):
- 加單檔到既有 group:`Stage 4: 記錄詳情頁 + 刪除流程`、`Stage 5: 拍照確認頁 + 多來源候選名稱`
- 整批分資料夾的 group 結構:看最近一個 `refactor:` 前綴的 commit

---

## 重新產生 App icon

```bash
python3 tools/make_icon.py
```

會直接覆蓋 `RecognizeLandmark/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`,Xcode 下次 build 就會用新版。要改顏色 / 造型直接改 `tools/make_icon.py` 上面那幾個常數(`top` / `mid` / `bot` / 塔的 width 參數等)。

依賴:`pip install Pillow`。

---

## 對單一 Swift 檔做語法檢查(不開 Xcode)

```bash
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun --sdk iphoneos swiftc -typecheck \
  -sdk "$SDK" \
  -target arm64-apple-ios17.2 \
  /path/to/file.swift
```

`exit=0` 就是過。**注意**:這只查單檔語法 / 找 SDK API,不是完整 build;有 cross-file dependency 的話還是要在 Xcode 跑。先前用這個方式驗證 `MKLocalSearch(request: poiRequest)` 確實可編譯(見 `bugs.md`)。

---

## 看 SDK header(找 API、查 init signature)

```bash
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
grep -A 1 "initWith" "$SDK/System/Library/Frameworks/MapKit.framework/Headers/MKLocalSearch.h"
```

換框架名 / header 名即可。Obj-C 的 `initWith...` 會被 Swift 匯入成對應的 `init(...)`,可以從 Obj-C header 推回 Swift 簽名。

---

## 查 PNG 是否真的變了(避免重跑 script 但其實沒變)

```bash
shasum -a 256 RecognizeLandmark/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

`tools/make_icon.py` 是 deterministic 的,沒改參數重跑會產生 byte-identical PNG。
