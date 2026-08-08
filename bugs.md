# Bugs / 踩坑

已知問題與曾經繞過 / 解過的坑。新坑加在最下方,寫上**現象**、**為什麼會發生**、**怎麼處理**。

---

## 已知問題

### 足跡地圖:pin 標籤在畫面左右邊緣會被裁掉

**現象**:記錄跨洲時(例如埃及 + 台灣),地圖自動縮放到能容納全部 pin,但貼在畫面邊緣
的 annotation 標題會被切一半,顯示成 `maining Luxor Obelisk`。截圖見
`docs/screenshots/04-map.jpg`。

**為什麼會發生**:auto-fit 的 region 只保證 pin 座標在畫面內,沒有替標籤文字留 padding。

**還沒處理**:可行方向是 fit 時多留一點邊界 inset,或標籤改成只在點選後顯示。

---

## 解過 / 釐清過的坑

### `MKLocalSearch(request: MKLocalPointsOfInterestRequest)` 看起來像 type mismatch,實際可編譯
**現象**:看到 `MKLocalSearch(request: poiRequest)` 直接傳 `MKLocalPointsOfInterestRequest`,header 又顯示兩個不同型別的 init,直覺以為會 type error。

**實際**:`xcrun swiftc -typecheck -sdk $(xcrun --sdk iphoneos --show-sdk-path) -target arm64-apple-ios17.2 ...` 確認 exit=0,兩種寫法都過。Swift 把 Obj-C 的 `initWithPointsOfInterestRequest:` 也匯入成 `init(request:)` overload。

**結論**:不要看 header 就假定不能編,有疑慮就跑 `swiftc -typecheck` 驗一下。

---

### Xcode GUI 選 Team 會旁路 `Signing.xcconfig`

**現象**:設了 `Config/Signing.xcconfig`(公開、空 Team ID)+ `Config/Signing.local.xcconfig`(gitignored,放真 Team ID)雙層架構,以為 Team ID 不會進 repo。實際在 Xcode 的「Signing & Capabilities」選 Team 後,`project.pbxproj` 的 `buildSettings` 莫名多出 `DEVELOPMENT_TEAM = <10碼>;`(Debug + Release config 各一)且 pbxproj 是 tracked,push 上去就洩漏 Team ID。

**為什麼會發生**:xcconfig 是 *base configuration*,優先序**低於** target 的 `buildSettings`。Xcode UI 不動 xcconfig,而是直接寫 target settings,於是 xcconfig 那層被覆寫;pbxproj 又是 tracked,Team ID 就跟著 commit。

**怎麼處理**:`.githooks/pre-commit` 會擋住含 10 碼大寫英數 Team ID 的 `pbxproj` / `xcconfig` commit(啟用方式見 `runbook.md`)。若被 hook 擋,從 `project.pbxproj` 移除那兩行 `DEVELOPMENT_TEAM = <10碼>;` 即可;build 時實際 Team ID 仍會從 gitignored 的 `Signing.local.xcconfig` 帶入,Xcode 能正常簽章。

**結論**:「我設了 xcconfig 雙層架構」**不是**安全保證,因為 Xcode UI 會旁路它。真正的保證是 pre-commit hook + `.gitignore`。

---

### Xcode 誤按專案比對按鈕後,以為檔案缺少 Source Code 選項

**現象**:開啟 `Info.plist` 時誤按工具列的專案比對／Version Editor 按鈕,畫面進入比對模式;右鍵選單找不到 `Open As → Source Code`,看起來像 plist 不能用原始碼檢視。

**為什麼會發生**:這是編輯器模式切換,不是檔案型別切換。`Info.plist` 本身仍是 XML 原始碼,只是 Xcode 進入了 Version Editor。

**怎麼處理**:從上方選單選 `Editor → Standard`,或點工具列的單一編輯器圖示離開比對模式。回到一般編輯器後,`Info.plist` 會直接顯示 XML。

**結論**:看到 XML 就代表已經是 Source Code 編輯器;此問題先檢查是否誤進 Version Editor,不必修改 `Info.plist` 的檔案型別。

---

### 自動化模擬器點擊:座標算對了還是點不到

做 README 截圖時要用滑鼠事件驅動模擬器,踩到三個獨立的坑,症狀都是「點了沒反應」:

**1. `System Events` 的 `click at` 對 app 畫面無效**
它是對 AX 元件做 click,不是送真實滑鼠事件。系統權限彈窗(原生 AX 元件)點得到,
app 自己畫的 UI 點不到。要用 `cliclick` 之類送真的 mouse down/up。

**2. Device bezels 打開時視窗幾何算不出螢幕位置**
`Show Device Bezels` 開著時,Simulator 視窗除了標題列還包含機身外框,
`視窗高 - scale × 852` 推出來的標題列高度是錯的,點擊會整體偏移(實測差 ~47 pt,
剛好落在畫面外或別的元件上)。從 Window 選單關掉 bezels 後,視窗內容 = 螢幕內容,
換算才成立。

**3. 同一台模擬器上有別的 UI test 在跑**
另一個專案的 `xcodebuild test` 綁到同一個 simulator UDID 時,它的 xctrunner 會自己
啟動 / 切換 app,畫面會莫名跳到別的 App。看起來像自己的點擊亂飛,實際不是。
用 `xcrun simctl spawn booted launchctl list | grep UIKitApplication` 可以看出來
誰在前景;確認後等它跑完,或改用另一台 device。

**結論**:自動化點擊不要假設「算對座標就會中」,每一步點完比對前後截圖再往下走。
完整流程寫在 `runbook.md`。
