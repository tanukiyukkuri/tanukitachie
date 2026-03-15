# ANALYTICS

この LP は GA4 を前提に、成果報告に使いやすい最低限のイベントを送る設計です。

## 設定方法

`index.html` の `window.ANALYTICS_CONFIG` を編集します。

```html
<script>
  window.ANALYTICS_CONFIG = {
    ga4MeasurementId: "G-XXXXXXXXXX",
    sponsorUrl: "",
    debug: false
  };
</script>
```

- `ga4MeasurementId`: GA4 の Measurement ID
- `sponsorUrl`: サポーター導線を使う場合だけ設定
- `debug`: `true` にすると console にイベントを出力

## 送信イベント

- `page_view`: ページ表示
- `section_view`: 各セクション到達
- `scroll_depth`: 25 / 50 / 75 / 100%
- `select_content`: LP 内リンククリック
- `download_interstitial_view`: ダウンロード前モーダル表示
- `download_interstitial_close`: ダウンロード前モーダルを閉じた
- `file_download`: ZIP ダウンロード開始
- `interstitial_navigation`: BOOTH など外部導線へ移動
- `sample_toggle`: 通常 / 左右反転の切り替え
- `sample_preview_open`: サンプル画像の拡大表示

## 成果報告で見やすい指標

- LP 閲覧数
- ダウンロードクリック数
- BOOTH 遷移数
- 利用条件 / FAQ まで到達した人数
- 25 / 50 / 75 / 100% のスクロール到達率

## GA4 側で Key Event にするとよい候補

- `file_download`
- `interstitial_navigation`
- `download_interstitial_view`
