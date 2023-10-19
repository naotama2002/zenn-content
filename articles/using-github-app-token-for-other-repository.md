---
title: "actions/create-github-app-token を利用してカレントリポジトリ以外を操作可能なトークンを生成する"
emoji: "🐶"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["githubactions", "github", "goreleaser", "#小ネタ"]
published: true
---

# 実現したいこと

[cybozu/assam](https://github.com/cybozu/assam) という OSS をリリースする際、GitHub Actions Workflow で GoReleaser を利用して Homebrew リリースしています。GoReleaser 実行時のトークンに GitHub Apps を利用するように変更します。
[goreleaser/goreleaser-action](https://github.com/goreleaser/goreleaser-action) を利用して Homebrew リリースしますが、指定リポジトリ(カレントリポジトリ以外)に Homebrew の formula ファイルを置くために、指定リポジトリ(カレントリポジトリ以外)への [Repository - Contents Write]((https://docs.github.com/ja/rest/overview/permissions-required-for-github-apps?apiVersion=2022-11-28#repository-permissions-for-contents)) 権限を持ったトークンを生成する必要があります。GitHub Actions Workflow でトークンを生成するために、 [actions/create-github-app-token](https://github.com/actions/create-github-app-token)^[セキュリティの観点からなるべく公式Actionを利用したいですよね] を利用します。

# 前提条件

## リポジトリ構成

同一 Organization 内で Go プログラムを管理するリポジトリと、Homebrew formura ファイルを置くリポジトリが別にあります。

今回の例では、下記 2 つのリポジトリを対象にします。

| 説明 | リポジトリ |
| ---- | ---- |
| Go言語で書かれたプログラム + [goreleaser/goreleaser-action](https://github.com/goreleaser/goreleaser-action) を Actions Workflow で利用するリポジトリ | naotama2002-org/assam |
| Homebrew formula ファイルを置くリポジトリ | naotama2002-org/homebrew-assam |


## GitHub App の設定

GitHub App 作成時、インストール時の条件は下記の通り。下記 Premission 設定し、複数リポジトリにインストールします。

- Permissions:
  - Repository - [Contents : Write and Read](https://docs.github.com/ja/rest/overview/permissions-required-for-github-apps?apiVersion=2022-11-28#repository-permissions-for-contents)
- GitHub App インストール時のリポジトリ指定:
  - naotama2002-org/assam
  - naotama2002-org/homebrew-assam
  の 2 つ^[goreleaser/goreleaser-action を利用する場合、両方のリポジトリにインストールする必要があります]

# 結論 ( GitHub Actions Workflow の書き方 )

naotama2002-org/assam リポジトリの GitHub Actions Workflow でこんな感じで書きます。
**actions/create-github-app-token で複数リポジトリ操作可能なトークンを生成するためには、repositorys: オプションで操作するリポジトリを指定する必要があります。**

GitHub Actions の Secrets に下記 2 つを設定します。
- APP_ID^[App ID はSecretsじゃなくても良いです]: GitHub App の App ID
- PRIVATE_KEY: [GitHub App の Private Key](https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps)

```yaml
jobs:
  release:
    runs-on: ubuntu-20.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/create-github-app-token@v1
        id: app-token
          with:
            app-id: ${{ secrets.APP_ID }}
            private-key: ${{ secrets.PRIVATE_KEY }}
            # actions/create-github-app-token でGitHub App インストール時に指定した複数リポジトリ操作可能なトークンを生成するためには、repositorys: オプションで操作するリポジトリを指定する必要がある
            repositorys: "assam,homebrew-assam"

        - uses: goreleaser/goreleaser-action@v5
          with:
            version: latest
            args: release --clean
          env:
            GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
```

goreleaser.yaml の brew 部分はこんな感じです。

```yaml
brews:
  - repository:
      owner: naotama2002-org
      name: homebrew-assam
    description: "Go sample"
```

:::message
actions/create-github-app-token を利用して、トークンを生成する際には、明示的に repositorys オプションで操作するリポジトリを指定する必要があります。

cybozu/octoken-action, tibdex/github-app-token の repositorys 指定なしだと、**GitHub App インストール時に指定した複数リポジトリを操作可能なトークン**が生成されます。しかし^[先行 GitHub App token生成 Action とデフォルトの考えが違うだけ]、actions/create-github-app-token は repositorys 指定なしだと、**カレントリポジトリのみ操作可能なトークン**が生成されます。

下記 `発生した課題` に記載していきます。
:::

# 発生した課題

## actions/create-github-token-app で生成したトークンで、goreleaser/goreleaser-action が失敗する

下記のように書いた Workflow で、app-id と private-key だけを指定して生成した GitHub App トークンを利用した GoReleaser が失敗する原因がわかりませんでした。

```yaml
    - uses: actions/create-github-app-token@v1
      id: app-token
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.PRIVATE_KEY }}

      - uses: goreleaser/goreleaser-action@v5
        with:
          version: latest
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
```

goreleaser/goreleaser-action でこんなエラーが発生しました。
```
* homebrew tap formula: could not update "assam.rb": PUT https://api.github.com/repos/naotama2002-org/homebrew-assam/contents/assam.rb: 403 Resource not 
```

GitHub App インストール時 `naotama2002-org/homebrew-assam` を指定していた。また、下記 2 つの Action 先に試していたため、`GitHub App インストール時に指定したリポジトリを、指定した Permission に従って操作可能なはず、操作できないのはバグじゃね？` という固定観念から逃れられませんでした。

- 少し前まで^[2023/10/19時点では actions/create-github-app-token に書き換えられている][GitHub Actions ワークフローで GitHub App を使用して認証済み API 要求を作成する](https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow)に記載されていた [tibdex/github-app-token](https://github.com/tibdex/github-app-token) で app_id, private_key のみを指定して、GitHub App インストール時に指定した複数リポジトリを操作ができていた
- [cybozu/octoken-action](https://github.com/cybozu/octoken-action) で github_app_id, github_app_private_key のみを指定して、GitHub App インストール時に指定した複数リポジトリを操作ができていた

tibdex/github-app-token だと、repositories 指定なしで、GitHub App インストール時に指定した複数リポジトリを操作可能なトークンが生成されます。
```yaml
      - uses: tibdex/github-app-token@v2
        id: app-token
        with:
          app_id: ${{ secrets.APP_ID }}
          private_key: ${{ secrets.PRIVATE_KEY }}

      - uses: goreleaser/goreleaser-action@v5
        with:
          version: "v${{ steps.tool-versions.outputs.goreleaser }}"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
```

cybozu/octoken-action だと、GitHub App インストール時に指定した複数リポジトリを操作可能なトークンが生成されます。
```yaml
      - uses: cybozu/octoken-action@v1
        id: app-token
        with:
          github_app_id: ${{ secrets.APP_ID }}
          github_app_private_key: ${{ secrets.PRIVATE_KEY }}
      - uses: goreleaser/goreleaser-action@v5
        with:
          version: "v${{ steps.tool-versions.outputs.goreleaser }}"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
```

## ドキュメントとソースコードを読もう

ちゃんとドキュメントに `現在のリポジトリのトークンを作成する` と書いてあります。
https://github.com/actions/create-github-app-token#create-a-token-for-the-current-repository

ちゃんとソースコードに `現在のリポジトリのトークンを作成する` と書いてあります。
https://github.com/actions/create-github-app-token/blob/main/lib/main.js#L27-L35

# 最後に

ちゃんとドキュメントを読もう、困ったらソースコードを読もう。

## リンク

GitHub Actions + GoReleaser を丁寧に説明されており参考になります。
https://zenn.dev/kou_pg_0131/articles/goreleaser-usage

もしかして Workflow を動かしている Repository しか操作できないトークンなのか？と気が付くきっかけをくれました。感謝！
https://zenn.dev/tmknom/articles/github-apps-token

cybozu/assam を GitHub App を利用してリリースするための確認をしていた捨てリポジトリ。汚いですが刺さないでください。普段業務では main リポジトリにゴリゴリコミットしたりしていません。
https://github.com/naotama2002-org/assam/blob/main/.github/workflows/release.yml

- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [cybozu/octoken-action](https://github.com/cybozu/octoken-action)
- [tibdex/github-app-token](https://github.com/tibdex/github-app-token)
- [goreleaser/goreleaser-action](https://github.com/goreleaser/goreleaser-action)
