---
title: "GitHub Actions Workflow を正確な間隔で実行する環境を AWS CDK で作成する方法"
emoji: "😺"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["github", "githubactions", "awscdk", "lambda", "#小ネタ"]
published: false
publication_name: "cybozu_ept"
---

# 実現したいこと

GitHub Actions の Workflow を 5 分ごと**正しい間隔**で Workflow をスケジュール実行したいが、GitHub Actions の [Cron( schedule トリガー )](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule) は遅延が発生^[実際に動かしてみると20分程度の遅延を観測しています]する仕様です。この課題を AWS Lambda + GitHub Actions API を利用して解消^[Workflow が fetch されてから実行されるまでの時間は、GitHub Actions 依存します]します。

:::message
https://zenn.dev/no4_dev/articles/14b295b8dafbfd
外部 Cron サービスを利用可能であれば、上記記事でサクッと解決できます！
:::

# 前提条件

AWS CDK を利用して、AWS Lambda から定期的に GitHub Actions の workflow_dispatch を実行する AWS 環境を実現します。

- AWS を利用します
- Node.js を利用します
- [AWS CDK](https://docs.aws.amazon.com/ja_jp/cdk/v2/guide/home.html) を利用します
- [GitHub Apps](https://docs.github.com/apps) を利用します
- GitHub App の [private key](https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps) を AWS Secrets Manager に登録します
- [workflow_dispatch ワークフロートリガー](https://docs.github.com/ja/actions/using-workflows/manually-running-a-workflow#configuring-a-workflow-to-run-manually)が設定されている GitHub Actions workflow を [API](https://docs.github.com/ja/rest/actions/workflows?apiVersion=2022-11-28#list-repository-workflows) で呼び出します

# 成果物(結論)

https://github.com/naotama2002/cron-github-actions-workflow-from-lambda

AWS CDK で Lambda 環境を構築する下記リポジトリを参照してください。全て有ります。


# やっていく

AWS 環境構築 + AWS Lambda 関数実装を AWS CDK を利用して行います。
今回作成したプロジェクトは https://github.com/naotama2002/cron-github-actions-workflow-from-lambda.git を参照ください。ポイントかもしれない部分だけ紹介していきます。

## 準備

### プロジェクト作成

```bash
npx aws-cdk@2 init app --language typescript
```

:::message
https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/tree/ba44023619263e55838eb7b7058a64be128fde88
がほぼ init した状態のコミットです。
:::


### [ブートストラップ](https://docs.aws.amazon.com/ja_jp/cdk/v2/guide/bootstrapping.html)

```bash
npm run cdk bootstrap
```

### esbuild インストール

`NodejsFunction` が esbuild を利用しているため、インストールします。

```bash
npm install esbuild -D
```

### deploy

```bash
npm run cdk deploy
```

AWS コンソールで Lambda 関数をみると `CronGithubActionsWorkflow-WorkflowDispatchxxxxxx-xxxxxxx` という名前で Lambda 関数が作成されています。

## 5分ごとに実行するスケジュール登録

### EventBridge 定義

Cron 形式で 5 分ごとに実行する EventBridge のルールを定義します。
https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/blob/main/lib/cron-github-actions-workflow-from-lambda-stack.ts#L36-L44

### 実行される GitHub Actions Workflow 定義

この Workflow が 5 分ごとに実行されることがゴール。

https://github.com/naotama2002-org/workflow-dispatch-zenn/blob/main/.github/workflows/workflow-dispatch.yaml

:::message
Workflow は naotama2002-org に置いてあります。
:::

## Lambda から GitHub Actions wofkflow_dispatch を実行する

### 準備

#### GitHub App を作成する

外部から workflow_dispatch を API 経由で実行するために、GitHub Apps を利用します。

必要なのは Repository Actions `Read and write` 権限を持ち、対象のリポジトリにインストールされていることです。

GitHub App 作成時の、デフォルトからの変更点を記載します。

- Expire user authorization tokens : OFF
- Permissions
  - Repository permissions
    - **Actions : Read and write**
- Webhook Active : OFF

GitHub App をインストールします。

- Only select repositories を選択して
  - `naotama2002-org/workflow-dispatch-zenn` を選択

:::message
https://zenn.dev/tmknom/articles/github-apps-token
GitHub Apps に関しては上記を読んでみましょう。
:::

GitHub App インストール結果
![](https://storage.googleapis.com/zenn-user-upload/0c6e720ca4c6-20231030.png)

#### GitHub App 情報を AWS Secrets Manager に登録する

[GitHub App インストールとして認証](https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation)で必要な情報を登録します。Lambda から利用し、GitHub App から Token を取得するために利用します。

登録するのは下記の 3 つです。

- GITHUB_APP_ID : GitHub App の ID
- GITHUB_SECRET_KEY : GitHub App の private key
- GITHUB_APP_INSTALLATION_ID : GitHub App の installation ID

:::message
GITHUB_SECRET_KEY は、改行を `\n` に変換して登録してください。

![](https://storage.googleapis.com/zenn-user-upload/37f30285ddc5-20231030.png)
Secrets Manager で、 GITHUB_SECRET_KEY を `キー/値` タブで見た時、上記のように private key が改行された状態で見えている必要があります。
:::

### 実行コード

#### Lambda から Secrets Manager から GitHub App の情報を得る

シークレット取得コードは[ここ](https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/blob/main/lib/secrets.ts)を見ていただくとして、Lambda 関数に必要な権限を付与します。

https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/blob/main/lib/cron-github-actions-workflow-from-lambda-stack.ts#L31-L34
AWS CDK で書くと直感的で良いですね。

#### workflow_dispatch を実行

octokit/auth-app で GitHub App から Token を取得します。
https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/blob/main/lib/trigger-ga-workflow-dispatch.ts#L13-L20

octokit/rest で workflow_dispatch を実行します。
https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/blob/main/lib/trigger-ga-workflow-dispatch.ts#L22-L40

## 実行結果

**5 分ごとに実行されていることが確認できます。**

![](https://storage.googleapis.com/zenn-user-upload/c206261102eb-20231030.png)

# あとがき

今回は、定刻にジョブが実行される CI/CD 環境から、GitHub Actions への移行時、定期実行ジョブの遅延実行が問題になりました。Lambda から GitHub Actions workflow_dispatch を API 経由で実行することにより、課題を解消するためを実装を紹介しました。

実務では Serverless framework v3.x で実装したのですが、[v4 発表](https://www.serverless.com/blog/serverless-framework-v4-a-new-model)に合わせ、移行先を検討しておくかーということで、今回は AWS CDK を検証してみました。
