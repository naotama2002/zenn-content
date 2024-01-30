---
title: "asdf→mise へ移行すると Renovate + asdf manager で golang/Node.js の 更新ができなくなった話"
emoji: "🦭"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["#mise", "#asdf", "github", "renovate"]
published: true
---

# はじめに

[asdf](https://asdf-vm.com/) から [mise](https://mise.jdx.dev) に移行したら Renovate の asdf manager で .tool-versions 更新ができなくなったお話です。

:::message
当問題は mise `2024.1.30` 以降で改善しており、 mise `2024.1.28` 以前のバージョンで発生します。2024/01/29 時点だからこそ意味ある記事です。
:::

# 結論

- Renovate + asdf manager で golang/Node.js を更新しているリポジトリで mise を利用する場合には mise `2024.1.30` 以降のバージョンを使いましょう。golang/Node.js を asdf 仕様で管理してくれます

# 発生した事象

`mise install golang 1.21.6` で golang 最新版を install 後、asdf 管理 (.tool-versions ファイル管理) するために `mise local golang 1.21.6` で 1.21.6 指定すると Renovate の asdf manager の管理下になりませんでした。困った。

利用していた mise のバージョンは `2024.1.20` です。
```bash
$ mise version
2024.1.20 macos-arm64 (2024-01-14)
```

golang を `golang 1.21.6` を指定した。
```bash
$ mise install golang 1.21.6
$ mise local golang 1.21.6
$ go version
go version go1.21.6 darwin/arm64
```

作成された `.tool-versions` を GitHub リポジトリへ git commit&push しました。

Renovate Dependency Dashboard を見ると、asdf 管理下に golang が入っていません。
```
asdf
  ▼ .tool-versions
```
.tool-versions の管理下に `golang <semVer>` が表示されません。

原因は `.tool-versions` の golang バージョン記述が `go 1.21.6` になっており、asdf manager が golang と認識できなくなったことです。

`mise local golang 1.21.6` した場合の .tool-versions ファイルは次の通りでした。
```
go 1.21.6
```

Renovate asdf manager は `golang 1.21.6` と書かれることを期待しています。
```
golang 1.21.6
```

# 解決策の検討

## Renovate 設定して .tool-versions の go を更新対象にする

```json
  "regexManagers": [
    {
      "fileMatch": ["^.tool-versions$"],
      "matchStrings": ["go (?<currentValue>\\d+\\.\\d+\\.\\d+)"],
      "datasourceTemplate": "golang-version",
      "depNameTemplate": "tool-versions/golang-version"
    }
  ],
```

いやー、.tool-versions に `go` で管理されるものは無いぞ！となりあまりやりたくない。

## mise にコントリビュート

`brew install rust` で Rust 開発環境構築して mise local の処理を読んで Rust なんもわからんけど branch&commit. 作成。

https://github.com/naotama2002/mise/commit/67ad6f70834b5a7f95fde5d1a8e8cdca115866ad

PR. 送るかーと思って [mise/CONTRIBUTING.md](https://github.com/jdx/mise/blob/main/CONTRIBUTING.md) 読んでたら、「お前その PR. は要るんか？　先に issue 立てて聞いてくれよな(意訳中の意訳)」っぽいことが書いてあったので issue 立てたら PR. 送る前に修正された^[この[使い捨てコード](https://github.com/jdx/mise/commit/14fb790ac9953430794719b38b83c8c2242f1759)みたいなのキレイにした PR. 作りたい気持ち]🎉。
https://github.com/jdx/mise/commit/14fb790ac9953430794719b38b83c8c2242f1759

検討していたら解決してしまいました。

# 解決した

mise `2024.1.30` 以降のバージョンを使いましょう。.tool-versions の golang/Node.js を asdf 仕様で管理してくれます。

# 移行した雑な感想(おまけ)

状況としては asdf で TOOL を管理しているリポジトリがたくさんあり、.tool-versions ファイルを git 管理下に置いており、GitHub 上で Renovate によりアップデート Pull Request が作成されています。こんな状況で asdf から mise に移行しました。

- `brew uninstall asdf; brew install mise` で導入簡単 (僕は macOS 環境)
- `.tool-versions` ファイル資産をそのまま流用可能で最高 (mise install すれば ok)
- asdf より速い？のは体感できていない (利用しているマシンが速いからだろうか)
- Rust で書かれてる最高？　(シェルスクリプトで書かれている大きなソフトより安定してそう)
- asdf のイメージでコマンド打てばだいたい動いてストレスない
- mise local `v2` 以降は `.tool-versions` では無く `.mise.toml` に情報を書き込むようになります。asdf から mise に乗り換え完了したら `.tool-versions` を使い続けるのか？検討が必要そう
