# Decisions

記架構決策、為什麼這樣選、放棄過哪些方案。新決策加在最下方並標日期。

---

## Stage 式漸進開發

**選擇**:把功能拆成 Stage 1(資料層)→ 2(拍照儲存)→ 3(TabBar+列表)→ 4(詳情/刪除)→ 5(確認頁/多來源候選),每個 Stage 一個 commit。

**Why**:這是個人學習專案,需要每階段都能跑、能 demo;一次到位反而難 debug、commit 也難回滾。

**替代方案**:整個架構先設計到位再寫(放棄,因為 SwiftData / SwiftUI / UIKit 怎麼搭事先沒答案,邊寫邊調比較實際)。

---

## UIKit 主流程 + SwiftUI 新功能混搭

**選擇**:相機畫面與 Vision 即時辨識(`ViewController`)留 UIKit + Storyboard;新功能(列表、詳情、確認頁)用 SwiftUI,透過 `UIHostingController` 接到 `UITabBarController`。

**Why**:`AVCaptureSession` + `AVCaptureVideoDataOutputSampleBufferDelegate` 在 UIKit 裡寫過、跑得起來,改成 SwiftUI 等於重寫一次相機。新功能用 SwiftUI 寫得快,也方便用 SwiftData 的 `@Query` / `@Bindable`。

**替代方案**:全 SwiftUI(放棄,要包裝 `AVCaptureSession` 為 `UIViewRepresentable` 多此一舉);全 UIKit(放棄,SwiftData 在 SwiftUI 裡比較順)。

---

## 雙層儲存:SwiftData metadata + 自管 PhotoStorage

**選擇**:`LandmarkRecord` 只存欄位(時間 / 名稱 / 信心 / 座標 / 筆記 / 照片**檔名**);照片本體以 UUID 為檔名的 JPEG 存在 Documents/photos/,由 `PhotoStorage` 管。

**Why**:把照片 blob 存進 SwiftData(或 Core Data)會讓 query 變慢、migration 變複雜、檔案備份成本高。檔名 + 檔案系統的方式簡單直觀,需要時用 `PhotoStorage.load()` 讀。

**代價**:刪除 `LandmarkRecord` 必須**同步**刪實體照片,否則會留孤兒檔。已在 `RecordsListView.deleteRecord` 與 `RecordDetailView.deleteRecord` 處理。

---

## 拍照後跳確認頁,而不是直接即存

**選擇**(Stage 5):按快門 → 同時跑影像 ML + POI 搜尋 + 反向地理編碼 → 確認頁讓使用者點選或編輯名稱、加筆記 → 確認才存。取消則完全丟棄(連照片檔都不寫)。

**Why**:純影像 ML 對地標辨識準度有限,GPS 拿到的具名 POI 反而更可靠;讓使用者多一道選擇/編輯機會,存下去的 label 品質明顯提升。取消不寫檔避免孤兒。

**Trade-off / 已知摩擦**:每張都要按確認,連拍場景會煩。已記入 `roadmap.md`「高信心時跳過確認頁」與「連拍 / 批次確認」。

---

## 影像 ML 分兩支:即時 HUD vs 一次性辨識

**選擇**:即時 HUD(`ViewController.captureOutput`)沿用每 0.5 秒一次的 `VNClassifyImageRequest`;按快門時的一次性辨識抽出到 `CaptureClassifier.swift`。

**Why**:即時跑頻率高,需要輕量;一次性可以慢、可以重(允許未來換 landmark 專用 Core ML 模型)。**未來換模型只動 `CaptureClassifier`,不必碰即時迴圈**。

**替代方案**:兩邊用同一支(暫不採,等實機驗證後再決定;見 README「替換成地標模型」第 4 點)。

---

## 候選排序:POI → geocode → image

**選擇**(`ViewController.mergeCandidates`):確認頁的候選 chip 順序固定為 MKLocalSearch POI 在前、CLGeocoder 反向地理編碼次之、影像 ML 最後;同名去重。

**Why**:POI 通常是「具名地點」(例:龍山寺),最可能是使用者要的答案;反向地理編碼次之(例:行政區、街道);影像 ML 在沒 GPS 或 POI 不準時兜底。

**Trade-off**:沒做動態 ranking(信心、距離綜合排序)。第一版固定順序夠用,未來看實際使用再調(待加進 roadmap)。

---

## App icon 程式化產生(Pillow)

**選擇**:`tools/make_icon.py` 用 PIL 直接畫 1024x1024 PNG,而非用 Figma / Sketch / 圖編軟體匯出。

**Why**:這是程式碼可重現的素材;改顏色 / 造型只要改參數重跑,不需要保留 .fig / .sketch 檔;diff 友善;不需要額外設計工具。

**Trade-off**:複雜的細緻效果(陰影、紋理、漸變陰影)用 PIL 寫起來比 Figma 麻煩。目前需求簡單,可接受。
