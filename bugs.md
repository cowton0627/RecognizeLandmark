# Bugs / 踩坑

已知問題與曾經繞過 / 解過的坑。新坑加在最下方,寫上**現象**、**為什麼會發生**、**怎麼處理**。

---

## 已知問題

(目前無)

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
