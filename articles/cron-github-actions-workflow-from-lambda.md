---
title: "GitHub Actions Workflow を定期実行できる環境を AWS CDK で作成する方法"
emoji: "😺"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["github", "githubactions", "awscdk", "lambda", "#小ネタ"]
published: true
publication_name: "cybozu_ept"
---

# 実現したいこと

定刻にジョブが実行される CI/CD 環境から GitHub Actions への移行する際に、GitHub Actions の定期実行ジョブの遅延実行が問題になりました。Lambda から GitHub Actions workflow_dispatch を API 経由で実行することにより課題を解消します。

GitHub Actions Workflow を 5 分ごと **正しい間隔(定期実行)** でスケジュール実行したいが、GitHub Actions の [Cron( schedule トリガー )](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule) は遅延が発生^[実際に動かしてみると20分程度の遅延を観測しています]する仕様です。この課題を AWS Lambda + [GitHub Actions API](https://docs.github.com/ja/rest/actions?apiVersion=2022-11-28) を利用して解決^[Workflow が fetch されてから実行されるまでの時間は、GitHub Actions 依存します]します。AWS 環境構築には AWS CDK を利用します。

:::message
https://zenn.dev/no4_dev/articles/14b295b8dafbfd
GitHub Actions API の Token を置く場所・外部 Cron サービスを利用可能等、要件を満たせば、上記記事でサクッと解決できます！
:::

# 前提条件

AWS CDK を利用して、AWS Lambda から GitHub Actions の workflow_dispatch を定期実行する AWS 環境を実現します。

- AWS を利用します
- Node.js を利用します
- [AWS CDK](https://docs.aws.amazon.com/ja_jp/cdk/v2/guide/home.html) を利用します
- [GitHub Apps](https://docs.github.com/apps) を利用します
- GitHub App の [private key](https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps) を `AWS Secrets Manager` に登録します
  - 本記事では `AWS Secrets Manager` を利用^[Secrets Manager を利用している仕組みを AWS CDK に置き換え検証しているため、Secrets Manager を利用しています]していますが、`AWS Parameter Store` でも要件を満たします。
- [workflow_dispatch ワークフロートリガー](https://docs.github.com/ja/actions/using-workflows/manually-running-a-workflow#configuring-a-workflow-to-run-manually)が設定されている GitHub Actions workflow を [API](https://docs.github.com/ja/rest/actions/workflows?apiVersion=2022-11-28#create-a-workflow-dispatch-event) で呼び出します

# 成果物(結論)

https://github.com/naotama2002/cron-github-actions-workflow-from-lambda

AWS CDK で AWS 環境を構築し、Lambda から GitHub Actions Workflow を実行する成果物は、上記リポジトリを参照してください。全てここにあります。

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
がほぼ aws-cdk init app した状態のコミットです。
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
```typescript
export class CronGithubActionsWorkflowFromLambdaStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
     :
     :
      // 5分ごとに実行
      new events.Rule(this, "WorkflowDispatchRule", {
        schedule: events.Schedule.expression("cron(0/5 * * * ? *)"),
        targets: [new targets.LambdaFunction(WorkflowDispatch,
          {
            retryAttempts: 0
          }
        )],
      });
```

### 実行される GitHub Actions Workflow 定義

この Workflow が 5 分ごとに実行されることがゴール。

```yaml
name: Workflow dispatch test

on:
  workflow_dispatch:

jobs:
  step:
    runs-on: ubuntu-latest
    steps:
        - run: echo Run workflow dispatch!
```

:::message
Workflow は naotama2002-org に置いてあります。
https://github.com/naotama2002-org/workflow-dispatch-zenn/blob/main/.github/workflows/workflow-dispatch.yaml
:::

## Lambda から GitHub Actions workflow_dispatch を実行する

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

#### Lambda 関数で利用する GitHub App の情報を Secrets Manager から 得る

シークレット取得コードは[ここ](https://github.com/naotama2002/cron-github-actions-workflow-from-lambda/blob/main/lambda/secrets.ts)を見ていただくとして、Lambda 関数に必要な権限を付与します。

```typescript
export class CronGithubActionsWorkflowFromLambdaStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // .env ファイル読み込み
    dotenv.config();
    // Secrets Manager の APN
    const stringSecretArn = process.env.AWS_SECRETS_MANAGER_APN;
     :
     :

      // AWS Secrets Manager への権限付与
      //   Secrets Manager の該当 APN の Read権限
      const smResource = Secret.fromSecretCompleteArn(this, "SecretsManager", stringSecretArn);
      smResource.grantRead(WorkflowDispatch);
```
.env ファイルから APN を読み込んで、権限を付与しています。AWS CDK で書くと直感的で良いですね。

#### workflow_dispatch を実行

GitHub Actions API を叩く部分は https://github.com/octokit/octokit.js を利用しています。

octokit/auth-app で GitHub App から Token を取得します。
```typescript
export const triggerWorkflowDispatch = async ({
  secrets,
}: triggerWorkflowDispatchParams): Promise<void> => {
  const octokit = new Octokit({
    authStrategy: createAppAuth,
    auth: {
      appId: secrets.GITHUB_APP_ID,
      privateKey: secrets.GITHUB_SECRET_KEY,
      installationId: secrets.GITHUB_APP_INSTALLATION_ID,
    },
  });
```

octokit/rest で workflow_dispatch を実行します。
```typescript
  await octokit.rest.actions
    .createWorkflowDispatch({
      owner: WORKFLOW_OWNER,
      repo: WORKFLOW_REPO,
      workflow_id: WORKFLOW_ID,
      ref: WORKFLOW_REF,
    })
    .then((_) => {
      console.log(
        `success: ${WORKFLOW_OWNER}/${WORKFLOW_REPO}/${WORKFLOW_ID}:${WORKFLOW_REF} workflow_dispatch`,
      );
    })
    .catch((error) => {
      console.log(
        `error: ${WORKFLOW_OWNER}/${WORKFLOW_REPO}/${WORKFLOW_ID}:${WORKFLOW_REF} workflow_dispatch`,
      );
      throw error;
    }
  );
```

## 実行結果

**5 分ごとに実行されていることが確認できます。**

![](https://storage.googleapis.com/zenn-user-upload/c206261102eb-20231030.png)

# あとがき

実務では [Serverless framework](https://www.serverless.com/) V3.x で実装したのですが、[V4 New Model](https://www.serverless.com/blog/serverless-framework-v4-a-new-model) に合わせ、移行先を検討しておくかーということで、今回は AWS CDK を検証してみました。
