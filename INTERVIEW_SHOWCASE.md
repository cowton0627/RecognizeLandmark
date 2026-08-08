# 景跡簿：面試展示完善計畫

更新日期：2026-07-22

## 展示目標

讓面試官在 3 分鐘內理解三件事：

1. **產品價值**：拍下或匯入照片，App 以影像、附近 POI 與地址共同協助收藏地標。
2. **工程深度**：UIKit 相機與 SwiftUI 功能混搭、Swift Concurrency、多來源 ranking、SwiftData 與照片檔案分層儲存。
3. **產品判斷**：辨識結果可修正、地點與畫面內容分離、資料 local-first，不用假裝模型永遠正確。

完成標準不是「功能很多」，而是現場流程穩、畫面一致、能回答設計取捨，且 repo 打開後容易理解與建置。

## 現況評估

### 已經適合拿來講的部分

- 相機即時 Vision HUD 與按快門後的一次性辨識分流。
- 影像、POI、reverse geocode 三路非同步查詢與候選合併。
- 使用者確認／更名／修正位置後才保存，避免把模型輸出當事實。
- SwiftData metadata 與 JPEG 檔案分離，刪除時同步清理。
- UIKit + SwiftUI 混合架構，適合說明漸進式改造而非為了追新技術重寫。
- local-first，不需帳號、後端或 tracking SDK。

### 目前會削弱 Demo 的問題

- 面試場地通常拍不到地標，室內實拍只會證明「同一 GPS 找到同一 POI」。
- 尚無所有記錄的足跡地圖，產品「景跡」的累積價值不夠直觀。
- 相機首頁與確認／列表／詳情的視覺語言還不完全一致。
- 權限拒絕、無網路、儲存失敗等狀態缺少完整、友善的 UI。
- 測試集中在 model 與 ranking，尚未覆蓋 capture orchestration、檔案清理及 migration。
- README 沒有截圖、架構圖、Demo 動圖或明確的面試導覽入口。
- 目前工作目錄累積多筆未提交修改；展示前需整理成可讀的 commits。

## 必做：Showcase MVP

### S1. 建立室內也必定成功的 Demo 路徑

進度：**相簿單張匯入、EXIF 日期／GPS、共用 CaptureFlow 已完成；Demo 素材與 reset 尚未完成。**

**功能**

- 從 Photos 選取一張既有地標照片。
- 優先讀取照片 EXIF 的時間與 GPS；沒有 GPS 時允許在地圖點選。
- 共用現有 `CaptureFlow` 與 `CaptureReviewView`，避免另寫一套辨識邏輯。
- 準備 3–5 張自己有權使用的台灣地標照片作為展示資料，例如台北 101、中正紀念堂、龍山寺；不要把素材直接塞進 production bundle，除非授權清楚。
- 提供「清除所有 Demo 記錄」或可重置方式，確保每次面試前可回到乾淨狀態。

**驗收**

- 在沒有走出面試會議室的情況下，90 秒內可完成匯入、確認名稱、修正位置與保存。
- 相機拍攝與相簿匯入走相同的候選 ranking、儲存及診斷邏輯。
- 無 EXIF、拒絕 Photos 權限及使用者取消均不會卡住或產生孤兒檔。

### S2. 補上「足跡地圖」

進度：**列表／地圖切換、100 公尺內聚合、pin 數量、縮圖預覽與詳情導覽已完成；等待實機驗收。**

**功能**

- 記錄頁提供「地圖／列表」切換。
- 所有有座標的記錄顯示在 MapKit；相近標記使用 clustering 或按地點聚合。
- 點 pin 顯示縮圖與名稱，再進入詳情。
- 無座標記錄仍保留在列表，不從產品中消失。

**驗收**

- 匯入 5 筆跨城市資料後，一眼可看出收藏分布。
- 同地點多張照片不會完全重疊而無法操作。
- 地圖選取、列表選取與刪除後狀態一致。

### S3. 把主要流程做成可放心現場操作的品質

進度：**相機拒絕權限與設定入口、辨識 loading、防重複操作、離線／無候選提示、前景恢復、保存失敗照片 rollback 已完成；等待完整實機壓力驗收與 Dynamic Type／VoiceOver。**

**功能與修正**

- 完成 `runbook.md` 的 P0 實機驗收清單，並在 `QA_REPORT.md` 留下裝置／iOS 版本、逐項結果與異常證據。
- 相機、位置、Photos 權限都提供用途說明、拒絕後替代流程與前往設定入口。
- 查詢中、無候選、離線、保存失敗使用一致的 loading／empty／error state。
- 修正快速連點快門、背景／前景切換、review dismiss 後 session 恢復等生命週期問題。
- 所有使用者可見文案統一繁體中文；修正相機權限目前仍是英文的問題。
- 支援 Dynamic Type，VoiceOver 能讀出快門、候選來源、影像信心與地圖操作。

**驗收**

- 依驗收清單連跑三輪，沒有 crash、卡死、重複 modal 或孤兒照片。
- 飛航模式與拒絕位置時仍能以影像結果／手動名稱完成保存。
- 主要操作在大字級下不截斷關鍵按鈕。

### S4. 建立工程可信度

進度：**CaptureFlow 已可注入 classifier／place lookup,並補兩路合併、單路降級、無位置與跨來源去重測試；PhotoStorage 已可使用隔離暫存目錄,並補 save/load/delete、壞檔與冪等刪除測試。保存 transaction、schema migration、UI test 與完整 `xcodebuild test` 尚未完成。**

**測試**

- `CaptureFlow`：注入 classifier／place lookup，測試兩路成功、一邊失敗、取消與排序。
- `PhotoStorage`：save/load/delete round trip、檔案不存在、JPEG 失敗路徑。
- `LandmarkRecord`：舊 `confidence` 到新 `imageConfidence` 的相容顯示。
- 刪除 use case：metadata 保存失敗時回滾照片；照片刪除失敗時可記錄並重試。
- 至少一條 UI test 覆蓋列表 → 詳情 → 刪除；相機硬體流程保留實機測試。

**工程整理**

- 把 `CaptureDiagnostics` 與儲存流程從 `ViewController` 拆成可注入 service。
- 對 SwiftData schema 建立明確 version／migration plan。
- 清除 stale 文件：`DECISIONS.md` 的固定排序說明需更新為目前 ranking。
- 確保 clone 後依 README 可一次 build；記錄最低 Xcode／iOS 與實際驗證版本。

**驗收**

- `xcodebuild test` 有可重現指令與成功結果。
- 關鍵 domain 邏輯不依賴相機硬體即可測試。
- Git 工作目錄乾淨，提交依「ranking／資料模型／UI／docs」等意圖拆分，而非一個巨大 commit。

### S5. 讓 GitHub repo 自己會說故事

README 首屏建議依序放：

1. App 名稱、一句話定位與 15–30 秒 GIF。
2. 三張畫面：拍攝／確認、足跡地圖、記錄詳情。
3. 「為什麼不是只用 Vision」：多來源流程圖。
4. Architecture：UIKit camera → CaptureFlow → SwiftUI review → SwiftData／PhotoStorage。
5. 關鍵取捨：local-first、可修正、地點與畫面內容分離。
6. Build／test 指令、限制與下一步。

素材不得包含公司名稱、辦公室座標、Personal Team ID 或其他私人資料。截圖使用自行拍攝且適合公開的照片。

## 加分項：Showcase MVP 穩定後再做

- Stage 6b 的最近記錄 strip；能強化「拍完立刻累積」的回饋。
- 年份／城市統計與一張可分享的回顧卡。
- 簡單搜尋：地點、畫面內容、日期。
- JSON metadata + 照片匯出，具體證明資料所有權。
- Instruments 報告：即時 Vision throttle 前後的 CPU、能耗或 dropped frames 比較。
- CI 在每次 push 執行 unit tests；README 顯示 build status。

暫不把專用全球地標模型列為展示前必做。能清楚說明目前模型限制、用 POI 補足、允許人工修正，比放入一個來源不明且效果不穩的模型更能展現工程判斷。

## 建議執行順序

| 順序 | 工作包 | 預估 | 展示價值 |
|---|---|---:|---|
| 1 | 整理目前 P0、完成實機驗收、修正文案 | 0.5–1 天 | 消除現場失敗風險 |
| 2 | Photos 匯入與 Demo 素材流程 | 1–2 天 | 室內也能穩定展示核心價值 |
| 3 | 足跡地圖與同地點聚合 | 1–2 天 | 讓產品名稱與累積價值成立 |
| 4 | 測試注入、儲存一致性、migration | 1–2 天 | 支持工程深入追問 |
| 5 | README 截圖、GIF、架構圖、Demo rehearsal | 0.5–1 天 | repo 與口頭敘事完整 |
| 6 | 最近記錄 strip／搜尋／統計 | 有餘裕再做 | 視覺與留存加分 |

## 三分鐘 Demo 腳本

### 0:00–0:30：問題與定位

「旅行照片很多，但過一陣子常忘記這是哪裡。景跡簿會把照片、拍攝位置與裝置上的影像辨識結合，讓使用者快速確認後，存成自己的私密地標收藏。」

### 0:30–1:30：Happy path

1. 從 Photos 匯入一張台北 101 照片。
2. 展示 POI／地址／影像三種候選與來源 icon。
3. 指出「地點」與「畫面內容」是兩個不同概念。
4. 儲存後立刻進入足跡地圖，點開剛新增的記錄。

### 1:30–2:15：可信與可修正

1. 匯入一張無 GPS 照片。
2. 在地圖手動選位置、重新搜尋附近。
3. 說明模型只提供建議，使用者確認才是資料真相。

### 2:15–3:00：工程取捨

- UIKit 保留穩定相機管線，SwiftUI 加速新頁面開發。
- `async let` 平行執行辨識與位置查詢。
- SwiftData 存 metadata、檔案系統存 JPEG，避免 blob 拖慢 query。
- 無帳號、無 analytics，照片與記錄預設留在裝置。

## 面試常見追問準備

- **為什麼不用全 SwiftUI？** 說明漸進式演進與 AVCaptureSession 既有穩定性。
- **為什麼 POI 優先？** 距離近的具名地點通常比通用 Vision label 更符合收藏需求，但 UI 不把它冒充影像信心。
- **如何處理錯誤？** 候選、人工更名、地圖修正、離線 fallback。
- **如何避免資料不一致？** 說明照片與 metadata 的 transaction 邊界，以及下一步的 rollback／cleanup strategy。
- **如何擴充模型？** `CaptureClassifier` 是替換點；即時 HUD 與拍照辨識刻意分流以控制效能。
- **隱私怎麼做？** local-first、無第三方 SDK；同時誠實說明 MapKit／CLGeocoder 查詢會由 Apple 系統服務處理。
- **如果有更多時間？** 先用實測首選採用率調 ranking，再評估專用模型，而不是先追求模型複雜度。

## 展示前一天 Checklist

- [ ] 使用實際展示 iPhone 完成完整驗收，關閉不必要通知。
- [ ] 準備 3–5 張授權清楚、辨識結果已確認的照片。
- [ ] 清除公司名稱、私人座標與測試垃圾資料。
- [ ] 保留少量好看的預載記錄，另確認 reset 流程。
- [ ] 錄一段離線備援 Demo；AirPlay／轉接器失效時仍可展示。
- [ ] README、測試結果與 Git commits 均可在沒有網路時打開。
- [ ] 準備 30 秒、3 分鐘與 10 分鐘三種版本的說法。
