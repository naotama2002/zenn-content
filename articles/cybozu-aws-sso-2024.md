---
title: "IAM Identity Center + Entra ID による SSO と複数 AWS アカウント切り替えのしくみ 2024年版"
emoji: "⚙"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws", "entraid", "sso"]
published: true
published_at: 2024-08-14 09:00 # JST
publication_name: "cybozu_ept"
---

:::message
この記事は、[CYBOZU SUMMER BLOG FES '24](https://cybozu.github.io/summer-blog-fes-2024/) (生産性向上セイサンシャインビーチ Stage) DAY 3 の記事です。
:::

こんにちは、サイボウズ生産性向上チームの [@naotama](https://x.com/naotama) です。
今回は、サイボウズ生産性向上チームの AWS 基盤開発活動の中から、AWS SSO に関する取り組み紹介したいと思います。

2019 年に生産性向上チームで構築した AWS SSO しくみ "AWS + Azure AD による Single Sign-On と複数 AWS アカウント切り替えのしくみ" を 2024 年に新しいしくみへ移行しました。本記事では新しく構築したしくみの紹介をしたいと思います。
https://blog.cybozu.io/entry/2019/10/18/080000

:::message
本記事では新しいしくみへの移行観点は記載しておりません。移行観点に関する内容は、[AWS SSO のしくみを AWS IAM Identity Center へ移行したはなし](https://www.docswell.com/s/naotama/524DJ1-2024-04-09-aws-sso-migration)(スライド)をご覧いただければと思います。
:::

# 目的

シングルアカウントで運用していると、人やチームが増えて規模が大きくなってきたときに権限管理が中央集権的になり、管理者への負担が増大してしまいます。また、新規ユーザーの登録だけでなく、退職時の削除漏れにも注意が必要です。利用者側に管理するパスワードが負担を負わせたくありません。

生産性向上チームではマルチアカウント構成によるシングルサインオン(以下 SSO)とチームに委譲できる権限管理のしくみを作ることでこれらの問題を解決し、社内で AWS を活用しやすい基盤を継続運用します。

継続運用性を高めるために^[[AWS CLI を使用して AssumeRole 呼び出しを行い、一時的なユーザー認証情報を保存する方法を教えてください](https://repost.aws/ja/knowledge-center/aws-cli-call-store-saml-credentials)記載のしくみを [cybozu/assam](https://github.com/cybozu/assam) を開発し実現していましたが、独自実装を無くし AWS 公式のしくみを採用することで将来同技術を継続利用できる可能性が高まると考えています]、AWS 公式のしくみである IAM Identity Center を採用します。
https://docs.aws.amazon.com/ja_jp/singlesignon/latest/userguide/what-is.html

# 全体構成と読み進めるための補足説明

## 全体構成
全体構成から一部を切り取りながら説明する部分がありますので、話の流れをわかりやすくするために全体構成図を置いておきます。

![全体構成図](https://storage.googleapis.com/zenn-user-upload/7215d3477cce-20240808.png)

:::message
サイボウズでは社員のアカウント(以下ユーザアカウントと記載)情報を Microsoft Entra ID で管理しています。
:::

## 許可セットという概念

![許可セット](https://storage.googleapis.com/zenn-user-upload/ae2156cb38cc-20240808.png)

IAM Identity Center では、許可セットという概念で権限を定義して、「誰が、どの AWS アカウントに、どの許可セット(権限)でアクセスするか」を設定して利用します。誰が = プリンシパル(ユーザ or グループ) です。
https://docs.aws.amazon.com/ja_jp/singlesignon/latest/userguide/permissionsetsconcept.html

表現の出典元:
https://dev.classmethod.jp/articles/multi-account-tips-ps-for-management-account/

# 実現されていること

**kintone + AWS SSO(IAM Identity Center) で AWS マルチアカウント管理・利用を最高にするしくみ！**です。

- 利用チーム/ユーザは kintone アプリにレコード登録**だけ**で、社内ユーザアカウントを利用し SSO で AWS アカウントを利用可能
- 管理者の作業基本不要（自動で必要な情報の同期・設定がおこなわれる）なし、エラーは Slack に通知されるため、通知を受けてユーザサポートもしくは解析作業

ユーザが必要な AWS アカウントで必要な権限を利用して開発がおこなえる！権限を得るために承認依頼待ちならない！を実現しています。

出勤登録くらいのユーザ負担で AWS アカウントを必要な権限で利用可能ですね！（消されるかもいろんな意味で）

## 利用チーム/ユーザの kintone アプリレコード登録

### 許可セット登録
![許可セット定義画面](https://storage.googleapis.com/zenn-user-upload/183db2ad6cbc-20240808.png)

kintone アプリに権限(許可セット)を登録することで、ユーザが利用する権限を定義できます。
権限は、[マネージドポリシー](https://docs.aws.amazon.com/ja_jp/singlesignon/latest/userguide/permissionsetpredefined.html)(AdministratorAccess/ Billing / ReadOnlyAccess …)や、インラインポリシーで設定可能です。

### ユーザアカウント x AWS アカウント x 許可セット割当登録

![ユーザアカウントとAWS アカウントと許可セットの紐づけ画面](https://storage.googleapis.com/zenn-user-upload/ad57b93812b0-20240808.png)
kintone アプリに `許可セット` / `ユーザアカウント x AWS アカウント x 許可セット割当` をレコード登録することで SSO のしくみを利用可能になっています。ユーザは kintone アプリにレコード登録するだけです！(大事なことなので 2 回言いました)


# SSO を使った AWS アカウントの構成概要

## AWS アカウントの整理方法
AWS アカウントは目的ごとに作成しています。
具体的には AWS Organizations の[組織単位(OU)](https://docs.aws.amazon.com/ja_jp/organizations/latest/userguide/orgs_manage_ous.html)を使って次のように整理しています^[OU の整理・活用はチームの中で issue としてあがっており OU の整理が進んでいく予定です]。
![OUの構成イメージ](https://storage.googleapis.com/zenn-user-upload/518a9ab712b0-20240808.png)

- root
  - admin
  管理用アカウントを配置
  - service
  この下にプロダクトごとの OU を作成し、さらにその下へ環境ごと(Production、Staging など)のアカウントを配置
  - professional
  組織横断型チーム用のアカウントを配置
  - business
  その他業務用のアカウントを配置
  - sandbox
  実験用のアカウントを配置

AWS Organizations を使うことで請求の一括化や、API を使ったアカウントの作成も行っています。 AWS Organizations の利用方法については、AWS の公式ドキュメントをご参照ください。
https://aws.amazon.com/jp/organizations/getting-started/

IAM Identity Center では IAM Identity Center の管理を AWS Organizations 配下のメンバーアカウントに委任可能です^[[IAM Identity Center 管理を委任して管理](https://docs.aws.amazon.com/ja_jp/singlesignon/latest/userguide/delegated-admin.html)]。今回の構成では admin OU 配下に委任先アカウントを作成し、強い権限を持つ AWS Organizations アカウントへのセキュリティ上の懸念を軽減しています。

## アカウント同期

### ユーザアカウントの管理
![Entra ID と IAM Identity Center のユーザアカウント同期](https://storage.googleapis.com/zenn-user-upload/39a1274b4433-20240808.png)

SSO ログインするためのユーザアカウントは Entra ID から IAM Identity Center へ 40 分毎に同期されています。全ての社内ユーザアカウントが同期されており、社内ユーザ全員が SSO のしくみを利用可能になっています。

### ログイン可能な AWS アカウントと許可セット情報管理

![kintone とAWS アカウント/許可セット同期](https://storage.googleapis.com/zenn-user-upload/fdde980e115f-20240808.png)

IAM Identity Center のマスターデータ(`許可セット` / `ユーザアカウント x AWS アカウント x 許可セット割当`)は kintone に置き、GitHub Actions Workflow を利用して自動同期することで簡単にメンテナンスできるようにしています。

- GitHub Actions workflow で 10 分毎にスケジュール実行し、ユーザアカウント x AWS アカウント x 許可セット割当をしています
- GitHub Actions workflow から AWS を操作するために [OIDC を利用して AWS 認証](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)します
- 割当プログラムは Go 言語で実装し(チームでは TypeScript or Go でツール実装することが多い)、2 つのプログラムが実行されています
  - 許可セットの割当
  - ユーザアカウント x AWS アカウント x 許可セット割当
- `管理アカウントへ割り当てている許可セット` が委任先アカウントで更新できなくなるため、IAM Identity Center 管理アカウントへのユーザアカウント x AWS アカウント x 許可セット割当は別枠で実施しています
  https://dev.classmethod.jp/articles/multi-account-tips-ps-for-management-account/

## AWS アカウントへのログイン方法

### AWS マネジメントコンソソールへのログイン
![アクセスポータル](https://storage.googleapis.com/zenn-user-upload/bb9e26cde30f-20240808.png)
ユーザは IAM Identity Center のアクセスポータル通じて、ログインする AWS アカウント/利用する許可セットを選択してログイン可能です。
https://docs.aws.amazon.com/ja_jp/singlesignon/latest/userguide/using-the-portal.html

### CLI でのログイン

![CLI でのログイン](https://storage.googleapis.com/zenn-user-upload/2b818906df1d-20240808.png)

`aws configure sso` で必要情報を設定後、`aws sso login` で AWS CLI (AWS API) を利用可能なクレデンシャルを取得できます。リモートシェルのような GUI が使えずブラウザを直接起動できない環境でも利用可能です。
https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/cli-configure-sso.html

# 運用で工夫していること

## kintone アプリレコード登録から AWS 環境への同期をユーザがトリガできる

IAM Identity Center のマスターデータ(`許可セット` / `ユーザアカウントとAWS アカウントと許可セット割当`)の同期は 10 分毎に実行していますが、「レコード登録/修正したから早く AWS 環境に反映させて動作確認したい」ということがあります。管理者へ依頼することなく、ユーザ自身で GitHub Actions Workflow を実行リポジトリの特定 issue で `/sync` とコメントすることで即時同期実行を可能にしています。

`/sync` とコメントすると bot が👀をつけて同期が始まります。
![プログラムから自動コメント](https://storage.googleapis.com/zenn-user-upload/f07b8a7be986-20240808.png)

## 許可セットの登録間違いは kintone アプリのレコードにコメント通知しユーザに直接通知

マネージドポリシーやカスタムポリシーを利用して許可セットを登録可能です。マネージドポリシー名の間違いや、JSON で登録するカスタムポリシー設定では、記述間違いが起こりがちです。その際のエラーを kintone アプリレコードコメントに直接書き込み(通知)することで、「ユーザが早く間違いに気がつける」「管理者がユーザへ個別に連絡しなくてもよく負担がない」を実現しています。

![](https://storage.googleapis.com/zenn-user-upload/1e79f85cae47-20240808.png)

# あとがき

## IAM Identity Center のショートカットリンク機能が最高な件

2024 年のアップデートで IAM Identity Center のアクセスポータルにショートカット作成機能がリリースされました。
https://aws.amazon.com/jp/about-aws/whats-new/2024/04/aws-iam-identity-center-shortcut-links-aws-access-portal/

- 利用する AWS アカウント
- 利用する許可セット
- アクセスする AWS サービス URL

を指定してショートカットを利用可能なのですが、この機能を利用してアラート通知を Slack へ飛ばす際に `特定 AWS アカウント の CloudWatch Logs` へ直接アクセスできるリンクを埋め込んだり、運用ドキュメントに `特定 AWS アカウントの ECS 画面` へのリンクを埋め込んだりできます。

複数 AWS アカウントを管理・運用しているチームでは、特定(目的) AWS アカウントへログイン → 目的のサービスへ移動を繰り返していたと思いますが、ショートカットを利用することでアカウント切り替えの手間がなくなりとても便利になりました。

:::message
弊社主催の Meetup で、「IAM によるスイッチロールから IAM Identity Center によるアカウント**切り替え**に移行したメリットはありますか？」と質問され、回答に困っていたのですが、いまなら **これです！これです！** と回答できます。移行に関する記載はしない！としてるのに記載しているのであとがきです。
:::

## Microsoft Entra ID と IAM Identity Center の連携設定

クラスメソッドさんの最高の記事を参考にしながら Entra ID と IAM Identity Center の連携設定が可能です(個人用 Entra ID + IAM Identity Center 連携時にもお世話になりました)。そのため本記事では連携方法に関する情報は記載しませんでした。クラスメソッドさん有益な記事を公開いただきありがとうございます。
https://dev.classmethod.jp/articles/federate-azure-ad-and-aws-iam-identity-center/

# お知らせ

## assam の GitHub リポジトリをアーカイブしました

https://github.com/cybozu/assam
IAM Identity Center の採用にともない、SSO の CLI 利用が `aws sso login` で可能になったため、assam はアーカイブしメンテナンスを終了しました。
