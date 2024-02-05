---
title: "Go の linter を golangci-lint から staticcheck に変更することになった話"
emoji: "🐶"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["golang", "linter"]
published: true
---

# はじめに

チームの Go プロジェクト linter には [golangci-lint](https://github.com/golangci/golangci-lint) が採用され、GitHub Actions Workflow で golangci-lint が実行されています。新規 Go プロジェクト作成時に「golangci-lint のどの linter を有効にしようか？チームにとって良い golangci-lint 設定とは？」を検討した結果、新しいプロジェクトでは [staticcheck](https://github.com/dominikh/go-tools) を採用しようとなった話です。

# 結論

## staticcheck を採用した理由
- チームで利用の多い VSCode + vscode-go に staticcheck がデフォルトで採用されている
  - [Go チーム](https://github.com/golang)が開発している vscode-go が [staticcheck を採用](https://github.com/golang/vscode-go/issues/189)している(Go チームへの信頼)
- VSCode + vscode-go + staticcheck の結果に満足できている (結果論)

## golangci-lint をやめた理由
- いろいろなプロジェクトを見てみたが `これが良さそう` という設定を導き出せなかった
  - 各チームで `linter に求めるものが違う` ため当たり前なんだと思う
  - 取捨選択をあきらめ golangci-lint に採用された linter を全てクリアすることは正義だ！として `enable-all: true` することは、モブプログラミングで開発するチームには `過剰` になりそう
- 多くの linter を設定した golangci.yml のメンテナンスコストがかかりそう
  - 設定ファイルのメンテナンスコストは最小にしたい
- 軽い設定を入れて徐々に入れたい制約が見つかったら追加していくスタイルが合っていると思う
  - 小さなツールを Go で書いてるチームなので追加したい制約発見駆動で golangci.yml を育てていくスタイルは合わなさそう(大きなプロジェクトで採用する場合は、チームで制約を入れるために golangci-lint 採用したくなりそう)

# 現状

チームの既存 Go プロジェクトから golangci.yml を拝借して作成した設定ファイルは次の通りです。

golangci.yaml
```yaml
linters:
  enable:
    - revive
    - gofmt
    - govet
```

golangci-lint の [default](https://golangci-lint.run/usage/linters/#enabled-by-default)(`errcheckm, gosimple, govet, ineffassign, staticcheck, unused`) + 3 つ(revice, gofmt, govet)の linter が有効になっている状態です。VSCode + vscode-go で開発してるメンバーが多いため、手元開発環境では staticcheck で linter が走っている状態です^[ ちゃんと golangci-lint の設定をしているメンバーがいるかもしれない]。

# 検討

## golangci-lint のどの linter を有効にしようか？

[golangci-ling: Linters](https://golangci-lint.run/usage/linters/) を 1 つ 1 つ理解して試して取捨選択していくのは厳しいため、「Go を採用していて、かつチームで利用している OSS や Go と言えば!で著名なチーム(会社) のリポジトリを見ながら良い感じの linter を選択できないか」という方法で検討しリストアップしました。

- Docker
  - Go といえば Docker でしょう
- Terraform
  - 毎日お世話になっている
- Kubernetes
  - 界隈で著名
- GitLab
  - Go の標準とスタイルガイドラインを書いてあり参考になりそう
- golangci
  - 本家のリポジトリ

各 OSS/チーム(会社)内のリポジトリ内でも設定が違うものもありますが、アクティブなリポジトリから 1 つ選出しています。

### docker/cli
https://github.com/docker/cli/blob/master/.golangci.yml#L1-L43

### hashicorp/terraform
https://github.com/hashicorp/terraform/blob/main/Makefile
- golangci-lint じゃなくて staticcheck だった

### kubernetes/kubernetes
https://github.com/kubernetes/kubernetes/blob/master/hack/golangci.yaml#L130-L142

### mercari/grpc-federation
https://github.com/mercari/grpc-federation/blob/main/.golangci.yml#L63-L98

### gitlab
https://gitlab.com/gitlab-org/language-tools/go/linters/goargs/-/blob/master/.golangci.yml?ref_type=heads#L69-93

### golangci/golangci-lint
https://github.com/golangci/golangci-lint/blob/master/.golangci.yml#L79-L130

各リポジトリを眺めて「各チームの思惑があって設定されおり(予想通りの千差万別)」、どこかのチームを参考に決めるのは難しいと感じました。

## チームにとって良い golangci-lint 設定とは？

「どこかのチームを参考に決めるのは難しい」という結論は出ましたが、であれば一番最初に調べた docker/cli を参考に設定を考えてみますか、とチーム用の golangci.yml 設定は作ってみた。

:::details 設定ファイルを作るために書いたメモです。
```yaml
linters:
  enable-all: false
  disable-all: true
  enable:
    - bodyclose # Checks whether HTTP response body is closed successfully.
      http 通信書くときに close 見てくれる、見てほしい

    - depguard
      利用してほしくないパッケージをガードしたい

    - gofmt # go fmt
      go fmt チェックはいる, vscode-go で入るので合わせたい

    - goimports # goimport
      goimports かけておきたい。vscode-go で入るので合わせたい gci にするか？悩む

    - gosec # Inspects source code for security problems.
      セキュリティチェックしてくれる

    - gosimple # default
      不要なコードを教えてくれる

    - govet # default
      コンパイラが検出しない疑わしい構文をチェックしてくれる

    - ineffassign # default
      不要な代入が行われている箇所を報告してくれる

    - misspell # Finds commonly misspelled English words in comments.
      僕はほしい

    - nakedret # Checks that functions with naked returns are not longer than a maximum size (can be zero).
      naked return はやめたい(みんなはどう？)

    - revive # Fast, configurable, extensible, flexible, and beautiful linter for Go. Drop-in replacement of golint.
      golint のかわり,,,なんだけど revive, staticcheck, gocritic が被ってる気がする。golangci-lint がうまく設定で調整してくれてるのだろうか

    - staticcheck # default
      linter

    - unconvert # Remove unnecessary type conversions.
      不要な型キャストをチェック

    - unparam # Reports unused function parameters
      未使用パラメータチェック

    - unused # default
      未使用な変数/型を教えてくれる

    - errcheck # default
      error チェックをしてないことを教えてくれる

    - gocritic # chekers (diagnostic, style, performance)
      いろいろ checker

    - sqlclosecheck
    - rowserrcheck
      bodyclose 入れるならこいつも入れたいな
```
:::

golangci.yml
```yaml
linters:
  enable-all: false
  disable-all: true
  enable: # please keep this alphabetized
    - bodyclose # Checks whether HTTP response body is closed successfully.
    - depguard # Go linter that checks if package imports are in a list of acceptable packages.
    - gofmt # go fmt
    - goimports # goimport
    - gosec # Inspects source code for security problems.
    - gosimple # [default] Linter for Go source code that specializes in simplifying code.
    - govet # [default] Vet examines Go source code and reports suspicious constructs, such as Printf calls whose arguments do not align with the format string.
    - ineffassign # [default] Detects when assignments to existing variables are not used.
    - misspell # Finds commonly misspelled English words in comments.
    - nakedret # Checks that functions with naked returns are not longer than a maximum size (can be zero).
    - revive # Fast, configurable, extensible, flexible, and beautiful linter for Go. Drop-in replacement of golint.
    - staticcheck # [default] staticcheck
    - unconvert # Remove unnecessary type conversions.
    - unparam # Reports unused function parameters
    - unused # [default] Checks Go code for unused constants, variables, functions and types.
    - errcheck # [default] Errcheck is a program for checking for unchecked errors in Go code. These unchecked errors can be critical bugs in some cases.
    - errorlint # Errorlint is a linter for that can be used to find code that will cause problems with the error wrapping scheme introduced in Go 1.13.
    - gocritic # chekers (diagnostic, style, performance)
    - sqlclosecheck # Checks that sql.Rows, sql.Stmt, sqlx.NamedStmt, pgx.Query are closed.
    - rowserrcheck # Checks whether Rows.Err of rows is checked successfully.

run:
  timeout: 10m

linters-settings:
  depguard:
    rules:
      main:
        deny:
          - pkg: io/ioutil
            desc: The io/ioutil package has been deprecated, see https://go.dev/doc/go1.16#ioutil
  revive:
    rules:
      - name: package-comments  # パッケージ/関数コメント disable
        disabled: true
issues:
  # The default exclusion rules are a bit too permissive, so copying the relevant ones below
  exclude-use-default: false

  # Maximum issues count per one linter. Set to 0 to disable. Default is 50.
  max-issues-per-linter: 0

  # Maximum count of issues with the same text. Set to 0 to disable. Default is 3.
  max-same-issues: 0
```

チーム用の golangci.yml 作った上で、チームの Go リポジトリで golangci-lint を動作させチェックしてみた結果「ほとんど何も検出されない」となりました。この結果を見て「モブプログラミングで実施される Go プロジェクトでは、linter が検出しそうな部分はモブの中で解決されている、また、VSCode のでデフォルト linter である staticcheck によってある良い感じになっている」と結論づけました。

# あとがき

僕の担当する直近新規 Go プロジェクトでは staticcheck を導入することにしましたが、golangci-lint もしくは、別 linter 探求を継続していきたいと思います。

golangci-lint の linter こつこつ増やしていく、この投稿めちゃ好き。
https://twitter.com/ma91n/status/1749039606895702279

# リンク

最高なのでみんな読みましょう。
https://zenn.dev/sanpo_shiho/books/61bc1e1a30bf27

弊社 Yakumo チームでも staticcheck 採用してるよ
https://blog.cybozu.io/entry/2021/02/26/081013

