---
title: "GitHub Actions Workflow を定期実行できる環境を Cloudflare workers Cron で作成する方法"
emoji: "🔥"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["github", "githubactions", "cloudflareworkers", "#小ネタ"]
published: true
---

# はじめに

https://zenn.dev/cybozu_ept/articles/cron-github-actions-workflow-from-lambda
上記記事の `GitHub Actions workflow_dispatch を API 経由で定期実行` を Cloudflare workers Cron で実現します。いくつか上記記事を参照しています。

# 前提条件

Cloudflare workers を利用して、GitHub Actions の workflow_dispatch を定期実行する環境を実現します。

- [Cloudflare workers](https://developers.cloudflare.com/workers/) を利用します
  - Cloudflare のアカウントが必要です
- TypeScript で実装します
- [GitHub Apps](https://docs.github.com/apps) を利用します
- GitHub App の [private key](https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps) を [Cloudflare workers secrets](https://developers.cloudflare.com/workers/configuration/secrets/) に登録します
- [workflow_dispatch ワークフロートリガー](https://docs.github.com/ja/actions/using-workflows/manually-running-a-workflow#configuring-a-workflow-to-run-manually)が設定されている GitHub Actions workflow を [API](https://docs.github.com/ja/rest/actions/workflows?apiVersion=2022-11-28#create-a-workflow-dispatch-event) で呼び出します

# 成果物(結論)

https://github.com/naotama2002/cron-github-actions-workflow-from-workers.git

Cloudflare workers から GitHub Actions Workflow を実行する成果物は、上記リポジトリを参照してください。全てここにあります。

# やっていく

## 準備

### プロジェクト作成

ここから始める
https://developers.cloudflare.com/workers/get-started/guide/

```bash
npm create cloudflare@latest
```

:::message
https://github.com/naotama2002/cron-github-actions-workflow-from-workers/commit/5ccdb97f18cb521c356f2e78c407b5176756e294
初期コミット
:::

### local 実行

```bash
npm install
npm run dev
```

## 5分ごとに実行するスケジュール登録

### スケジュールは wrangler.toml で設定

```toml
[triggers]
crons = ["*/5 * * * *"] # 5分ごとに実行
```

### スケジュール実行の確認

wrangler dev --test-scheduled を実行する

```bash
npm run start
```

実行確認

```bash
curl "http://localhost:8787/__scheduled?cron=*+*+*+*+*"
```

実行すると

```
trigger fired at * * * * *: success
[mf:inf] GET /__scheduled 200 OK (208ms)
```

と表示され、

```typescript
async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
  // A Cron Trigger can make requests to other endpoints on the Internet,
  // publish to a Queue, query a D1 Database, and much more.
  //
  // We'll keep it simple and make an API call to a Cloudflare API:
  let resp = await fetch('https://api.cloudflare.com/client/v4/ips');
  let wasSuccessful = resp.ok ? 'success' : 'fail';

  // You could store this result in KV, write to a D1 Database, or publish to a Queue.
  // In this template, we'll just log the result:
  console.log(`trigger fired at ${event.cron}: ${wasSuccessful}`);
},
```

が、実行されていることがわかります。

:::message
npm run start 実験時のコード
https://github.com/naotama2002/cron-github-actions-workflow-from-workers/blob/5ccdb97f18cb521c356f2e78c407b5176756e294/src/index.ts#L43-L48
:::

### Deploy

```bash
npm run deploy

> cron-github-actions-workflow-from-workers@0.0.0 deploy
> wrangler deploy

 ⛅️ wrangler 3.16.0 (update available 3.19.0)
-------------------------------------------------------
Total Upload: 0.45 KiB / gzip: 0.31 KiB
Uploaded cron-github-actions-workflow-from-workers (0.80 sec)
Published cron-github-actions-workflow-from-workers (3.74 sec)
  https://cron-github-actions-workflow-from-workers.xxxxxx.workers.dev
  schedule: */5 * * * *
Current Deployment ID: 65xxxxxxxxxx-xxxxx-xxxx-xxxxxxxxxx
```

Deploy が成功すると Cloudflare の Worker&Pages のページで確認できます。
![](https://storage.googleapis.com/zenn-user-upload/fc8c6d2cf929-20231208.png)

Cron の実行ログ...(少し不安な感じ)
![](https://storage.googleapis.com/zenn-user-upload/deafb94f428a-20231208.png)

### 実行される GitHub Actions Workflow 定義

https://zenn.dev/cybozu_ept/articles/cron-github-actions-workflow-from-lambda#%E5%AE%9F%E8%A1%8C%E3%81%95%E3%82%8C%E3%82%8B-github-actions-workflow-%E5%AE%9A%E7%BE%A9

## Cloudflare workers Cron から GitHub Actions workflow_dispatch を実行する

### 準備

#### GitHub App を作成する

こちらを参考にお願いします。
https://zenn.dev/cybozu_ept/articles/cron-github-actions-workflow-from-lambda#github-app-%E3%82%92%E4%BD%9C%E6%88%90%E3%81%99%E3%82%8B

#### GitHub App 情報を Cloudflare workers secrets に登録する

登録するのは下記の 3 つです。

- GITHUB_APP_ID : GitHub App の ID
- GITHUB_SECRET_KEY : GitHub App の private key
- GITHUB_APP_INSTALLATION_ID : GitHub App の installation ID

wrangler コマンドで secret を登録していきます。
```bash
npx wrangler secret put GITHUB_APP_ID
npx wrangler secret put GITHUB_APP_INSTALLATION_ID
```

GITHUB_SECRET_KEY はコンソールで設定しました。
:::message
GitHub App から Private key を download すると [PKCS#1](https://github.com/gr2m/universal-github-app-jwt#readme) フォーマットでした。これをそのまま利用すると

```
Error: [universal-github-app-jwt] Private Key is in PKCS#1 format, but only PKCS#8 is supported. See https://github.com/gr2m/universal-github-app-jwt#readme
```

とエラーになりました。https://github.com/gr2m/universal-github-app-jwt#readme に従って

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in private-key.pem -out private-key-pkcs8.pem
```

で PKCS#8 に変換したものを利用すると、Workflow Dispatch が実行されました。
:::

値の設定は、下記のように対話式で入力します。
```bash
npx wrangler secret put GITHUB_APP_ID --name cron-github-actions-workflow-from-workers
 ⛅️ wrangler 3.16.0 (update available 3.19.0)
-------------------------------------------------------
✔ Enter a secret value: … ******
🌀 Creating the secret for the Worker "cron-github-actions-workflow-from-workers"
✨ Success! Uploaded secret GITHUB_APP_ID
```

設定するとこんな感じになります。
![](https://storage.googleapis.com/zenn-user-upload/eeb3e6cad848-20231209.png)

コマンドラインから設定すると encrypted な状態で登録されますね。

コンソールから登録する場合は `Encrypt` は手動で実施します。
![](https://storage.googleapis.com/zenn-user-upload/c17403050023-20231208.png)

コマンドラインツールから設定時に、Encrypt しない方法は無さそうです。安全側に振られていてよい感じです。

```bash
npx wrangler secret
wrangler secret

🤫 Generate a secret that can be referenced in a Worker

Commands:
  wrangler secret put <key>     Create or update a secret variable for a Worker
  wrangler secret delete <key>  Delete a secret variable from a Worker
  wrangler secret list          List all secrets for a Worker

Flags:
  -j, --experimental-json-config  Experimental: Support wrangler.json  [boolean]
  -c, --config                    Path to .toml configuration file  [string]
  -e, --env                       Environment to use for operations and .env files  [string]
  -h, --help                      Show help  [boolean]
  -v, --version                   Show version number  [boolean]
```

### 実行コード

#### スケジュール実行される関数で利用する GitHub App の情報を Cloudflare workers secrets から得る

登録した値は [Env interface として定義することで利用できます](https://developers.cloudflare.com/workers/configuration/environment-variables/)。

```typescript
export interface Env {
  // GitHub App の ID
  GITHUB_APP_ID: string;
  // GitHub App の private key
  GITHUB_SECRET_KEY: string;
  // GitHub App の installation ID
  GITHUB_APP_INSTALLATION_ID: string;
}

export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
  await triggerWorkflowDispatch({ appId: env.GITHUB_APP_ID, secretKey: env.GITHUB_SECRET_KEY, installationId: env.GITHUB_APP_INSTALLATION_ID });
  },
};

```

#### workflow_dispatch を実行

GitHub Actions API を叩く部分は https://github.com/octokit/octokit.js を利用しています。

octokit/auth-app で GitHub App から Token を取得します。
```typescript
export const triggerWorkflowDispatch = async ({
  appId,
  secretKey,
  installationId
}: triggerWorkflowDispatchParams): Promise<void> => {

  const octokit = new Octokit({
    authStrategy: createAppAuth,
    auth: {
      appId: appId,
      privateKey: secretKey,
      installationId: installationId,
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

![](https://storage.googleapis.com/zenn-user-upload/129580cfc73f-20231209.png)

# あとがき

Cloudflare workers Cron から GitHub Actions workflow_dispatch `きっちり 5分ごとに`実行することができました。

# Tips

GitHub App の private key を Cloudflare workers の [Environment variables](https://developers.cloudflare.com/workers/configuration/environment-variables/) に登録しましたが、Encrypt せずに登録すると、シークレットっぽい情報を検知して、キーごと消されます。キーごと消されるのでびっくりしますが、セキュアな仕様ということでよい感じです。