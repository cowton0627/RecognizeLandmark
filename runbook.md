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

完整測試 target：

```bash
xcodebuild test \
  -project RecognizeLandmark.xcodeproj \
  -scheme RecognizeLandmark \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

若出現 `SwiftDataMacros ... malformed response` 或 `Platform Not Installed`,代表本機 Xcode platform／macro plugin 環境尚未就緒,不是單一測試 assertion 失敗。先在 Xcode Settings → Components 安裝對應 iOS Simulator runtime,重啟 Xcode 後再跑。

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

---

## 重新產生 README 截圖(模擬器)

`docs/screenshots/` 裡除了 `01-camera.jpg`(取景畫面只能實機拍)以外,都是在模擬器上
跑真實流程截下來的。要換素材或改版重截:

**1. build + 裝到模擬器**

```bash
xcodebuild -project RecognizeLandmark.xcodeproj -scheme RecognizeLandmark \
  -destination 'id=<simulator-udid>' -derivedDataPath /tmp/dd build
xcrun simctl install booted /tmp/dd/Build/Products/Debug-iphonesimulator/RecognizeLandmark.app
```

**2. 準備乾淨狀態**

```bash
xcrun simctl uninstall booted com.example.RecognizeLandmark   # 清掉舊記錄與照片檔
xcrun simctl install booted <上面那個 .app>
xcrun simctl privacy booted grant camera com.example.RecognizeLandmark
xcrun simctl privacy booted grant location com.example.RecognizeLandmark
xcrun simctl ui booted appearance light
xcrun simctl status_bar booted override --time "9:41" --wifiBars 3 --cellularBars 4 \
  --batteryState charged --batteryLevel 100
```

**3. 餵素材**:`xcrun simctl addmedia booted <照片>`。照片內嵌的 EXIF GPS / 拍攝時間
會被 `PhotoImportService` 直接採用,所以拿真實地標照就能讓 POI 搜尋回真名字,不必假造
定位。沒有 GPS 的照片可用 Pillow 補寫 GPS IFD(`exif.get_ifd(0x8825)`,值要用
`Fraction` 不是 `(num, den)` tuple,否則 `save()` 會丟 `TypeError`)。

**4. 驅動 UI**:模擬器不吃 `simctl` 的點擊指令,用 `cliclick`(`brew install cliclick`)
送真實滑鼠事件。`System Events` 的 `click at` 只對原生 AX 元件有效(系統權限彈窗可以,
app 畫面不行)。座標換算:

```
scale  = 視窗寬 / 393              # iPhone 15 的 point 寬
titleH = 視窗高 - scale * 852
screenX = 視窗X + devX * scale
screenY = 視窗Y + titleH + devY * scale
```

**先關掉 Window → Show Device Bezels**,否則視窗含機身外框,上式會整個偏掉(見
`bugs.md`)。點擊偶爾會被吃掉,寫成「點完比對前後截圖,沒變就重點」比較穩。

**5. 截圖 + 壓縮**

```bash
xcrun simctl io booted screenshot raw/02-capture-review.png
python3 tools/prep_screenshots.py raw --format jpg --width 640
```

原始素材(HEIC、實機截圖)不要放進 repo,只留 `docs/screenshots/` 下壓縮後的版本。

---

## P0 實機驗收清單

相機與位置無法由模擬器完整驗證。每次改動 capture flow 後，在實機逐項確認：
實際展示版的裝置資訊、逐項結果與異常證據統一記錄在
[`QA_REPORT.md`](./QA_REPORT.md)，不要只勾選清單後遺失測試環境。

- [ ] 首次啟動允許相機與位置，可完成拍攝、確認、保存
- [ ] 拒絕位置權限仍可拍攝，確認頁顯示無位置且能手動輸入名稱
- [ ] 關閉網路時 POI／geocode 無結果不會卡住，影像候選或時間 fallback 仍可保存
- [ ] 確認頁「重新搜尋附近」會更新候選，不會重複名稱
- [ ] 「修正位置」點選地圖後，pin、附近候選與最後保存座標一起更新
- [ ] 修改候選名稱後可保存；空白名稱不可保存
- [ ] 取消確認不建立 SwiftData record，也不產生照片檔
- [ ] 從列表與詳情刪除時，record 與照片檔都被移除
- [ ] 快速連點快門不會重複開啟確認頁，返回後相機可繼續運作
- [ ] 辨識期間顯示 loading，快門與相簿按鈕不能重複觸發
- [ ] 拒絕相機權限會顯示「前往設定」，且相簿匯入仍可使用
- [ ] 從設定重新允許相機後回 App，不需重啟即可恢復取景
- [ ] App 進背景再回前景，相機可恢復且不會同時啟動兩個 session
- [ ] 模擬 metadata 保存失敗時，剛寫入的 JPEG 會被清除

Debug console 的 `Capture diagnostics` 只包含累計次數與平均保存秒數，不含照片、名稱或座標。用於人工測試時比較候選覆蓋率、首選採用率、手動命名率與保存時間。

### Photos 匯入驗收

- [ ] 選取含 GPS 的地標照片，確認頁地圖位於原拍攝位置，保存時間是原拍攝時間
- [ ] 選取無 GPS 照片，確認頁顯示無位置，且可透過「修正位置」完成保存
- [ ] 在系統 picker 按取消，不停止相機、不建立記錄
- [ ] 選取 iCloud 尚未下載或無法解碼的照片，顯示錯誤且相機仍可使用
- [ ] 匯入後取消確認，不建立 metadata 或照片檔
- [ ] 匯入後保存，列表、詳情、影像內容與影像信心皆正確

### 足跡地圖驗收

- [ ] 三筆跨城市記錄能自動縮放至同一畫面
- [ ] 點 pin 顯示正確縮圖、地點、日期，點摘要卡可進入詳情
- [ ] 100 公尺內兩筆記錄聚合為一個 pin 並顯示 `2`
- [ ] 從詳情刪除聚合中的一筆，返回後數量立即更新
- [ ] 無座標記錄仍出現在列表，但不出現在地圖
- [ ] 全部記錄皆無座標時，地圖顯示可理解的空狀態
