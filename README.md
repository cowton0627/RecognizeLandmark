# RecognizeLandmark

用 iPhone 後鏡頭即時辨識畫面內容,可以拍照保存成記錄,並在地圖上回顧的 iOS App。

辨識採「**多來源候選**」策略:按下快門時平行跑三件事——(1) Apple Vision 影像分類(回答「是什麼類型」)、(2) `MKLocalSearch` 附近 POI 搜尋、(3) `CLGeocoder` 反向地理編碼(後兩者一起回答「是哪個具體地點」)——把候選帶入確認頁讓使用者點選或編輯後才存。日常使用 GPS 拿到的具名 POI(例:龍山寺、85 大樓)通常比純影像辨識可靠;影像 ML 目前用 `VNClassifyImageRequest`(輸出 building / tower / church 這類通用標籤),未來可替換為地標專用的 Core ML 模型,只需要動 `CaptureClassifier.swift`。

---

## 功能

- **相機 tab**:即時取景 + 每 0.5 秒辨識一次,顯示信心 ≥ 20% 的前 3 名(僅作為拍照前的視覺回饋)。
- **拍照確認頁**:按下快門後同時跑「附近 POI / 反向地理編碼 / 影像 ML」三路候選,跳出確認頁讓使用者點選候選 chip 或自己編輯名稱、加筆記,確認才正式存。取消則丟棄(不留孤兒照片檔)。
- **記錄 tab**:時間倒序的列表,每一列顯示縮圖、名稱、時間、座標(沒有的話顯示「無位置」)與信心度百分比;支援左滑刪除。空列表時會引導去相機分頁拍第一張。
- **詳情頁**:大圖、地圖標記(MapKit)、可編輯的筆記、右上角刪除確認。

---

## 環境需求

- macOS + Xcode 15 以上
- iOS 17.2 以上(實機測試;模擬器無相機)
- Swift 5.0
- 一台可用後鏡頭的 iPhone

---

## 建置與執行

1. 用 Xcode 開啟:

   ```bash
   open RecognizeLandmark.xcodeproj
   ```

2. 在 Xcode 上方選擇你的 iPhone 作為執行目標(模擬器無法用相機)。
3. 第一次 build 之前,設定你自己的 signing:

   ```bash
   cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
   ```

   然後編輯 `Config/Signing.local.xcconfig`:

   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   PRODUCT_BUNDLE_IDENTIFIER = com.yourname.RecognizeLandmark
   ```

   `Signing.local.xcconfig` 已被 git 忽略,不會把個人 Team ID 或 bundle id commit 進公開 repo。也可以直接在 Xcode 的 `Signing & Capabilities` 選自己的 Team;若 Xcode 改到專案檔,請確認不要把個人簽章資訊提交出去。
4. 按 `⌘R` 執行。
5. App 啟動後會依序請求相機與位置權限,允許後即可開始使用。

### Signing 疑難排解

- `Signing for "RecognizeLandmark" requires a development team`:尚未設定 `DEVELOPMENT_TEAM`;請建立 `Config/Signing.local.xcconfig` 或在 Xcode 選 Team。
- `Bundle identifier ... is not available`:請把 `PRODUCT_BUNDLE_IDENTIFIER` 改成你帳號底下唯一的值。
- 公開版預設使用 `com.example.RecognizeLandmark`,只適合作為 clone 後的安全預設值;實機執行通常需要改成自己的 bundle id。

---

## 操作

### 相機 tab
- 啟動後畫面會顯示即時辨識結果(信心 ≥ 20% 的前 3 名),沒到門檻時顯示「(無辨識結果)」。這只是 HUD 視覺回饋,**不會直接被存進記錄**。
- 按快門 → 暫停取景 → 同步跑影像 ML、`MKLocalSearch` 附近 POI(半徑 100 m)、`CLGeocoder` 反向地理編碼 → 跳出確認頁。
- 確認頁可以:點候選 chip(POI / geocode / image 三種來源用不同 icon 標示)、改名稱、加筆記、看地圖預覽。沒有任何候選時(例如拒絕位置權限且影像 ML 都低於門檻),預填欄位會放當下時間戳記。
- **只有按「儲存」才寫入 SwiftData + 寫照片檔**;按「取消」就完全丟棄,不會留下孤兒檔。

### 記錄 tab
- 時間倒序列表,點任一筆進入詳情。
- 列表左滑可直接刪除;詳情頁右上角垃圾桶會跳確認對話框。
- 詳情頁可編輯筆記,變更會即時寫回 SwiftData。

---

## 專案結構

```
RecognizeLandmark/
├── RecognizeLandmark.xcodeproj/      # Xcode 專案
├── tools/
│   └── make_icon.py                  # 用 Pillow 重新產生 1024x1024 app icon
└── RecognizeLandmark/
    ├── App/
    │   ├── AppDelegate.swift
    │   └── SceneDelegate.swift       # 程式建立 TabBarController(相機 / 記錄)
    ├── Camera/
    │   └── ViewController.swift      # 相機 + 即時 HUD 辨識 + 拍照流程
    ├── CaptureReview/                # 拍照後的確認頁流程
    │   ├── CaptureCandidate.swift    # 候選資料模型(POI / geocode / image / fallback)
    │   ├── CaptureClassifier.swift   # 一次性影像 ML(換 Core ML 地標模型只動這支)
    │   ├── PlaceLookup.swift         # MKLocalSearch + CLGeocoder
    │   └── CaptureReviewView.swift   # SwiftUI 確認頁(大圖 / chip / 地圖 / 筆記)
    ├── Records/                      # 記錄列表 + 詳情
    │   ├── RecordsListView.swift     # SwiftUI 記錄列表(@Query)
    │   └── RecordDetailView.swift    # SwiftUI 詳情頁(大圖 / Map / 筆記 / 刪除)
    ├── Storage/                      # 資料層
    │   ├── LandmarkRecord.swift      # SwiftData @Model:時間/名稱/信心/座標/筆記
    │   ├── Persistence.swift         # SwiftData ModelContainer 共用
    │   └── PhotoStorage.swift        # Documents/photos/ 下的 JPEG 自管儲存
    ├── Services/                     # 系統 wrapper
    │   └── LocationProvider.swift    # CoreLocation 取當下座標
    └── Resources/
        ├── Base.lproj/
        │   ├── Main.storyboard       # 相機畫面 UI(含 recognizedLabel)
        │   └── LaunchScreen.storyboard
        ├── Assets.xcassets/          # 含 AppIcon.appiconset(1024x1024 PNG)
        └── Info.plist                # NSCameraUsageDescription / NSLocationWhenInUseUsageDescription
```

---

## 資料儲存

- **記錄(metadata)**:SwiftData(`LandmarkRecord`),欄位包含時間、辨識名稱、信心度、照片檔名、經緯度、筆記。
- **照片(影像本體)**:不存進 SwiftData,放在 App Documents 下的 `photos/` 目錄,以 UUID 為檔名的 JPEG(壓縮品質 0.85),由 `PhotoStorage` 統一管理。
- **刪除**:刪除一筆記錄時會同步清掉對應照片檔,避免孤兒檔案。

---

## 權限

- `NSCameraUsageDescription`:即時辨識與拍照所需。
- `NSLocationWhenInUseUsageDescription`:拍照當下記錄座標,讓詳情頁可以用地圖回顧位置;拒絕也能正常使用,只是不會有地圖。

---

## 隱私

這個 App 完全在本機運作:沒有自己的後端、沒有 analytics 或 tracking SDK、不會把你的照片或位置上傳到任何遠端伺服器。

- **相機**:畫面僅用於即時辨識 HUD 與拍照,不錄影、不外送。
- **位置**:只在按下快門時取一次當下座標,記在那筆記錄上;拒絕位置權限也能正常使用。
- **照片**:存在 App 本機沙盒(`Documents/photos/`),刪除記錄時連同照片檔一起刪除。
- **記錄 metadata**:存在本機 SwiftData,不外送。
- **Apple 系統服務**:拍照時會用 `MKLocalSearch`(附近 POI 搜尋)與 `CLGeocoder`(反向地理編碼),這兩個是 Apple 提供的系統服務,座標會送到 Apple 處理,依 Apple 隱私政策處理。

---

## 替換成地標模型

要從通用分類換成具名地標辨識:

1. 取得一個地標分類用的 `.mlmodel`(例如以 Google Landmarks 訓練、轉成 Core ML 的版本)。
2. 把 `.mlmodel` 拖進 Xcode 專案,確認 Target Membership 勾選 `RecognizeLandmark`。
3. 改 `CaptureClassifier.swift`(拍照確認頁用的一次性辨識),把 `VNClassifyImageRequest` 換成 `VNCoreMLRequest` 包該模型——這支只在按下快門時跑一次,允許用較重的模型。
4. (可選)`ViewController.swift` 內的即時 HUD 也用 `VNClassifyImageRequest`,但跑頻率高(每 0.5 秒一次),預設保留輕量版;若想兩邊用同一個模型,改 `captureOutput(_:didOutput:from:)` 裡那個 request 即可,**注意效能與發熱**。

---

## App icon

`tools/make_icon.py` 用 Pillow 程式化產生 1024x1024 PNG(暖色日落漸層 + 白色塔身 + 塔尖發光點 + 4 角檢視框)。要調整顏色或造型:

```bash
python3 tools/make_icon.py
```

執行後會直接覆蓋 `RecognizeLandmark/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`,Xcode 下次 build 就會用新版。

---

## 授權

本專案以 MIT License 授權,完整條款見 [LICENSE](./LICENSE)。

App 本體沒有第三方 runtime 相依,只用 Apple 系統 framework(Vision / AVFoundation / MapKit / CoreLocation / SwiftData / SwiftUI / UIKit)。`tools/make_icon.py` 僅在開發端執行,使用 [Pillow](https://python-pillow.org/)(HPND License)。
