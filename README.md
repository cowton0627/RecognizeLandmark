# RecognizeLandmark

用 iPhone 後鏡頭即時辨識畫面內容,可以拍照保存成記錄,並在地圖上回顧的 iOS App。

目前使用 Apple Vision 內建的 `VNClassifyImageRequest` 做通用圖像分類(輸出 building / tower / church 這類通用標籤)。後續可替換為地標專用的 Core ML 模型,得到具名地標(例:101、Eiffel Tower)。

---

## 功能

- **相機 tab**:即時取景 + 每 0.5 秒辨識一次,顯示信心 ≥ 20% 的前 3 名。
- **拍照保存**:按下快門時,把當下畫面、辨識結果、信心度與位置一起存成記錄。
- **記錄 tab**:時間倒序的列表,顯示縮圖、名稱與時間;支援左滑刪除。
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
3. 第一次 build 之前,在 `Signing & Capabilities` 設定你自己的 Team。
4. 按 `⌘R` 執行。
5. App 啟動後會依序請求相機與位置權限,允許後即可開始使用。

---

## 操作

### 相機 tab
- 啟動後畫面會顯示即時辨識結果(信心 ≥ 20% 的前 3 名)。
- 沒有達到信心門檻時會顯示「(無辨識結果)」。
- 按快門即可把當下畫面與辨識結果存成一筆記錄。

### 記錄 tab
- 時間倒序列表,點任一筆進入詳情。
- 列表左滑可直接刪除;詳情頁右上角垃圾桶會跳確認對話框。
- 詳情頁可編輯筆記,變更會即時寫回 SwiftData。

---

## 專案結構

```
RecognizeLandmark/
├── RecognizeLandmark.xcodeproj/      # Xcode 專案
└── RecognizeLandmark/
    ├── AppDelegate.swift
    ├── SceneDelegate.swift           # 程式建立 TabBarController(相機 / 記錄)
    ├── ViewController.swift          # 相機 + Vision 即時辨識(UIKit)
    ├── LandmarkRecord.swift          # SwiftData @Model:時間/名稱/信心/座標/筆記
    ├── Persistence.swift             # SwiftData ModelContainer 共用
    ├── PhotoStorage.swift            # Documents/photos/ 下的 JPEG 自管儲存
    ├── LocationProvider.swift        # CoreLocation 取當下座標
    ├── RecordsListView.swift         # SwiftUI 記錄列表(@Query)
    ├── RecordDetailView.swift        # SwiftUI 詳情頁(大圖 / Map / 筆記 / 刪除)
    ├── Base.lproj/
    │   ├── Main.storyboard           # 相機畫面 UI(含 recognizedLabel)
    │   └── LaunchScreen.storyboard
    ├── Assets.xcassets/
    └── Info.plist                    # NSCameraUsageDescription / NSLocationWhenInUseUsageDescription
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

## 替換成地標模型

要從通用分類換成具名地標辨識:

1. 取得一個地標分類用的 `.mlmodel`(例如以 Google Landmarks 訓練、轉成 Core ML 的版本)。
2. 把 `.mlmodel` 拖進 Xcode 專案,確認 Target Membership 勾選 `RecognizeLandmark`。
3. 在 `ViewController.swift` 把 `VNClassifyImageRequest` 換成 `VNCoreMLRequest`,使用該模型即可。
