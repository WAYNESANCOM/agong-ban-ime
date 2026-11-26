# 阿公的ㄅ半輸入法

給 macOS 用的「ㄅ半」注音輸入法，跟以前 Windows 的舊注音一樣，一個字一個字選。

## 功能

- 大千鍵盤排列
- 打完注音按聲調查字：空白是一聲，`6` 是ˊ、`3` 是ˇ、`4` 是ˋ、`7` 是˙
- 直式選字窗，每頁 9 個，按 `1` 到 `9` 選字，空白或 `↓` `↑` 翻頁，`Esc` 取消
- 沒選字就繼續打，會自動選第一個字
- 聯想詞：選完字跳出常接的字詞，`Shift`+數字選，空白翻頁
- 標點：`Shift`+`,` 是「，」、`Shift`+`.` 是「。」、`Shift`+`/` 是「？」、`[` `]` 是「」
- 符號表：按 `` ` `` 或 `Ctrl`+`Option`+`,`
- 按住 `Shift` 約 0.8 秒再放開，切換中文與英數
- 打數字：注音模式下數字鍵是注音（例如 `1` 是ㄅ），要打數字有兩種方法：
  - 按一下大寫鎖定鍵（Caps Lock）讓燈亮，數字鍵就直接出數字，打完再按一次關掉。燈亮時英文字母會是大寫。
  - 按住 `Shift` 約 0.8 秒再放開，切到英數模式，數字和英文都照原樣打，打完再長按一次切回注音。
  - 右邊的數字鍵盤在注音模式下也會打成注音。
- `Shift`+字母直接打英文：大寫鎖定燈沒亮是小寫，亮著是大寫
- `Shift`+空白切換全形與半形
- `Ctrl`+`Shift`+`F` 或輸入法選單的「簡體輸出」，切換輸出繁體或簡體字

## 下載安裝

到 [Releases](https://github.com/WAYNESANCOM/agong-ban-ime/releases/latest) 下載最新的 `BopomofoHalf-版本.pkg`，雙擊照畫面安裝（需要輸入電腦密碼）。裝完請登出再登入，然後到選單列的輸入法選單點「ㄅ半注音」。安裝檔已用 Apple Developer ID 簽章並通過公證。

## 從原始碼安裝

需要 macOS 13 以上和 Xcode（只用到 `swiftc`）。

```sh
./install.sh
```

會建置 `build/BopomofoHalf.app`，裝到 `~/Library/Input Methods/`，並向系統登記。第一次裝完，到選單列的輸入法選單點「ㄅ半注音」。

若要在 App Store 版 LINE 這類沙盒 App 裡使用，輸入法必須用 Developer ID 簽章並經 Apple 公證。鑰匙圈裡有 Developer ID Application 憑證時，帶上 App Store Connect API 金鑰的環境變數執行，安裝前會自動簽章、公證：

```sh
ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… ./install.sh
```

第一次安裝後，請登出再登入（或重開機）。LINE 這類從 App Store 下載的 App，只認得登入時已經裝好的輸入法；沒有重新登入，在這些 App 裡會切不過去。

只要建置不安裝：

```sh
./build.sh
```

## 檔案

- `Sources/Engine.swift`：打字與選字邏輯
- `Sources/InputController.swift`：接收按鍵、送字給 App
- `Sources/CandidateWindow.swift`：選字窗與聯想詞視窗
- `Resources/zhuyin.json`：注音對照字表（1,312 個讀音、14,070 字）
- `Resources/assoc.json`：聯想詞表

## 字庫來源

選字順序照 Windows XP 舊注音（ㄅ半）的字表 `phon.tbl`、`phonptr.tbl`、`phoncode.tbl`，只收 Big5 字；聯想詞照 Windows 的相關字詞表 `lcphrase.tbl`、`lcptr.tbl`。
