# Roadmap

之後可能會做的開發項目。已完成的進度去看 `git log`,這裡只記「還沒做、但想過要做」的事。

新想到的加在最下方。決定要做的可以升到頂端;放棄的搬到「不做」區並寫上理由。

---

## 之後想做

### Stage 6b:相機首頁手繪風動態元素 → **下一個**
6a(視覺骨架,童趣手繪風)已完成。6b 把首頁從靜態升級成有「動態反應」與「累積感」。

**最近記錄縮圖 strip**(底部、快門上方一條橫向滑動)
- `UICollectionView` 或 `UIHostingController(UIScrollView)`,從 SwiftData 抓最近 10 筆記錄
- 每張縮圖用 `Sketch` 配色裝飾(微旋 ±2°、奶油 padding、棕墨細邊)— 像剪貼簿
- 點縮圖 → 跳到該筆 detail
- Empty state:「還沒拍過,試試看吧 →」手寫感 placeholder
- 首頁拍完一筆 → strip 自動更新最左

**Reticle 高信心 pulse**
- 影像 ML 最高信心 ≥ 0.6 時,reticle 4 個角輕微脈動(scale 1.0 → 1.06 → 1.0,1.2s 一輪)
- 用 `CAKeyframeAnimation` on transform.scale,加 ease-in-out
- < 0.6 自動停止

**拍照 radial 暖色 flash**
- 按下快門瞬間從畫面中央往外擴一圈暖色(`Sketch.accentWarm` → 透明)
- ~0.3s 漸隱
- 用一個 `CAGradientLayer` 圓形 mask 動畫

**改動檔案**
- 新增 `Camera/RecentRecordsStrip.swift`(SwiftData fetch + UICollectionView 或 SwiftUI hosting)
- 修改 `Camera/SketchUI.swift`(reticle pulse、shutter flash helper)
- 修改 `Camera/ViewController.swift`(掛 strip、觸發 pulse / flash)

**不在這次範圍**
- Strip 的拖拉重新排序、向左滑刪除(屬於 records tab 的事)
- 確認頁(`CaptureReviewView`)手繪化
- TabBar icon 換成手繪版本

- 出處:6a 完成後自然延伸;當初 6a/6b 拆分時對齊
- Commit:單一 commit `Stage 6b: 首頁動態元素 + 最近記錄 strip`

### 換成 Landmark 專用 Core ML 模型
目前 `VNClassifyImageRequest` 輸出 building / tower / church 這類通用標籤,要拿到具名地標(101、Eiffel Tower)需要換成 landmark 訓練的 `.mlmodel`。
- 出處:README「替換成地標模型」章節、DECISIONS.md「影像 ML 分兩支」
- 主改動點:`CaptureClassifier.swift` 把 `VNClassifyImageRequest` 換成 `VNCoreMLRequest`(這支只在按下快門時跑一次,允許用較重的模型)
- 待實機驗證後再決定:即時 HUD(`ViewController.swift`,每 0.5 秒一次)是否也換同一支 Core ML 模型,還是繼續用輕量 `VNClassifyImageRequest`;評估點是效能、發熱、電池

### 高信心時跳過確認頁
目前每張都跳確認頁,在景點連拍時會煩。當「附近 POI 距離很近 + 影像 ML 信心很高」時直接存,降低摩擦。
- 出處:Stage 5 設計時刻意延後,等實際使用過再定門檻
- 待決:門檻值(距離幾 m / 信心幾 %)、跳過時的視覺回饋(toast?)

### MKLocalSearch 半徑可調
目前 `PlaceLookup.swift` 寫死 100 m。不同場景(室內 / 大型景點 / 鬧區)效果差很多。
- 出處:Stage 5 commit 後的後續討論
- 想法:Settings 頁開放使用者調,或依當下定位精度自動縮放

### 候選動態 ranking
目前 `ViewController.mergeCandidates` 候選 chip 順序固定:POI → geocode → image,沒考慮 POI 距離、影像 ML 信心、CLGeocoder 精度。第一版固定順序夠用,實際使用後可能需要更細的排序。
- 出處:DECISIONS.md「候選排序:POI → geocode → image」trade-off(原文標「待加進 roadmap」)
- 想法:用「來源權重 × 信心 × 距離衰減」算 score 排序;分數差太小時退回固定順序避免抖動
- 待決:各來源權重、距離衰減函數、是否在 UI 顯示分數或只是排序

### 候選結果快取
短時間在同一地點反覆拍時,不重複打 `MKLocalSearch` / `CLGeocoder`(也省電)。
- 出處:Stage 5 plan「不在這次範圍」
- 待決:cache key(座標四捨五入到幾位小數)、TTL

### 連拍 / 批次確認
按住快門連拍時,改用 batch 確認頁(一次給多張),而不是每張跳一次。
- 出處:Stage 5 plan「不在這次範圍」
- 跟「高信心 skip」可能會合併成同一個流程設計

---

## 不做(已決定放棄)

(目前無)
