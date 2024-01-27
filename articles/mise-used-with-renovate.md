---
title: "asdf で困ってないけど mise に移行したはなし"
emoji: "🐶"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["#mise", "#asdf", "github", "renovate"]
published: false
---

# はじめに

仕事の環境、個人環境ともに asdf から mise に移行したおはなしです。移行して感じたことをメモ代わりに書いてます。 mise が何者か？はいろんなところに書いてあるので割愛します。
:::message
mise は 「[ミーズ(meez)](https://mise.jdx.dev/about.html)」と発音するらしいです。
:::

https://mise.jdx.dev/

# 雑な感想

- `brew uninstall asdf; brew install mise` で導入簡単 ( 僕は macOS 環境 )
- `.tool-versions` ファイルの資産をそのまま流用可能 ( mise install すれば ok )
- asdf より速い？のは体感できていない ( 利用しているマシンが速いからだろうか )
- Rust で書かれてるね ( シェルスクリプトで大きなソフト書いてるより安定してそう )

## Renovate で TOOL の自動更新をしているリポジトリで mise を使う場合

.tool-versions が無いディレクトリで使い始める場合

mise v2024.1.30 より前のバージョンで使う場合

## Plugin が無い場合に Plugin を自動インストールしてくれる

## TOOL　が install されていないことを教えてくれる

`.tool-versions` に記載されてる TOOL が install されていないことを教えてくれる

node 20.10.0 を利用しているリポジトリに cd すると

```bash
$ pwd
~/dev/foot
$ cat .tool-versions
nodejs 20.10.0
```

node@20.10.0 がインストールされていないと教えてくれる
```bash
$ cd ~/dev/foo
mise missing: node@20.10.0
```

このファイルに記載されているバージョンの node@20.10.0 が無いよと教えてくれる。好き❤️
```bash
mise list
Plugin  Version            Config Source                                         Requested
node    20.10.0 (missing)  ~/ghq/github.com/naotama2002/pomotimer/.tool-versions 20.10.0
```

# おわりに

mise に移行してよかった。これからも mise を利用していきたいし、コントリビュートしていきたい。
