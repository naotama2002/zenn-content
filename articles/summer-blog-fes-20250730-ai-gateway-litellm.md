---
title: "AI Gateway を AI 開発生産性爆アゲ業務ソンで実装した話"
emoji: "⛱️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws", "aigateway", "litellm"]
published: true
published_at: 2025-07-30 00:00 # JST
publication_name: "cybozu_ept"
---

:::message
この記事は、[CYBOZU SUMMER BLOG FES '25](https://cybozu.github.io/summer-blog-fes-2025/) の記事です。
:::

こんにちは、サイボウズ生産性向上チーム + AI やっていきチームの [@naotama](https://x.com/naotama)^[今回の記事は生産性向上チームとしての人格です] です。  
今回は、サイボウズ生産性向上チームで 3 日間にわたって実施された「AI 開発生産性爆アゲ業務ソン」で AI Gateway を実装した取り組みを紹介したいと思います。

# 背景

サイボウズには AI やっていきという AI 推進チームがあり、組織横断で AI に関連するさまざまな活動をしています。チーム活動のひとつに「社内の AI 基盤構築」があります。課題として「作りたい基盤はあるが実装できていない」があり、それを解決するため、[開発生産性を高めてサイボウズを加速する](https://www.docswell.com/s/cybozu-tech/5R2X3N-engineering-productivity-team-recruitment-information#p3) をミッションに掲げて活動している [生産性向上チーム](https://zenn.dev/p/cybozu_ept) に開発が依頼されました。

スピード感を持って基盤構築をするために「AI 開発生産性爆アゲ業務ソン」と銘打って 2025/07/22–24 の 3 日間、次の 2 チームで活動しました。

- リモートコーディングエージェント基盤開発  
  Claude Code Action を AWS 基盤込みでシュッと使える基盤を開発する
- AI Gateway 基盤開発  
  開発者が LLM モデルを各種プロバイダーとの契約なしにシュッと使える基盤を開発する

# モチベーション

開発者・チームが LLM を利用した開発をする際に「AWS と契約して Bedrock を利用する」までの各種手続きをスキップし、使いたいタイミングで各種プロバイダーの LLM モデルを利用可能な状態を提供する！  
そのために OpenAI API 仕様準拠の AI Gateway を用意する。

# AI Gateway

## 要件

1. OpenAI API 準拠の API を提供する  
   各種 LLM ライブラリでほぼサポートされているため、利用者の負担が小さい。

2. 社内で開発者向けに提供する  
   社内ネットワークに閉じて API を提供する。

3. 開発者が利用したいタイミングで利用開始できる（人の手を介さない）環境を提供する  
   kintone アプリでレコード登録するだけで `API Key` が自動払い出し！運用者に負担をかけない。

4. メトリクスを提供し、運用者が利用状況を把握できるようにする  
   アクセス状況や LLM モデルの利用状況を可視化する。

## Gateway 機能

AI Gateway を実装した経験から、[LiteLLM](https://www.litellm.ai/) の [LiteLLM Proxy Server (LLM Gateway)](https://docs.litellm.ai/docs/simple_proxy) を利用前提とし、業務ソン前半に Docker を利用した LiteLLM Proxy Server をローカルに構築して要件を満たせるか確認しました。

- OpenAI API 準拠の API を提供できる  
- 開発者に `API Key` を払い出すための API を備えている

確認の結果、外部から `API Key` をコントロールできる API が充実している LiteLLM は素晴らしい！となりました。LiteLLM の SSO 機能を使えば開発者自身で `API Key` を発行できますが、今回は OSS 版を利用するため LiteLLM 側にユーザを持たせることは避け、外部からコントロールできることが大切でした。

## メトリクス機能

当初は [Langfuse](https://langfuse.com/) と LiteLLM を連携させる想定でしたが、LiteLLM が提供するメトリクスだけで今回の要件を満たせそうだったため、Langfuse 連携は見送りました。

入出力ログを見ながらのプロンプト管理や LLM-as-a-Judge を行いたいなど、追加要望があれば Langfuse 連携を検討します。

API Key 単位やチーム単位でのメトリクスが提供されており要件を満たせていました。  
![](https://storage.googleapis.com/zenn-user-upload/efaf54a9d0e2-20250727.png)

## インフラ (AWS)

AWS には社内ネットワークに接続された VPC を用意し、ALB + ECS (Fargate) + Aurora Serverless for PostgreSQL で LiteLLM をサービスしています。

![](https://storage.googleapis.com/zenn-user-upload/0955cbebca83-20250727.jpg)

コンテナ実行環境に ECS を採用しています。ECS on EC2 ではなく Fargate にしたのは私の趣味です。3 日間で構築して稼働まで持っていくスピード感を重視し、好き＆経験豊富な ECS Fargate を採用しました。EKS？できるだけ避けたい派なので察していただけると幸いです。

インフラは Terraform で構築し、ECS Service / Task は [ecspresso](https://github.com/kayac/ecspresso) で管理しています。最近は「インフラ構築が終わったら `terraform destroy` で壊せること → `terraform apply` で再構築できること」を確認するようにしています。

### Terraform + ecspresso

![](https://storage.googleapis.com/zenn-user-upload/99e84781a186-20250727.png)

Terraform は Production, Staging など環境ごとにディレクトリを分けています。

```shell
$ cd ./terraform/environments/production
$ aws sso login
$ terraform <command>
```

ecspresso も Production, Staging など環境ごとにコントロールできる構成です。

```shell
$ cd ./terraform/deploy-ecs/production
$ aws sso login
$ ecspresso <command>
```

ECS Task で扱う環境変数を環境ごとに変更するため、`ecs-task-def.jsonnet` を置き、ecspresso の [Jsonnet functions](https://github.com/kayac/ecspresso/blob/v2/README.md#jsonnet-functions) を利用しています。

## `API Key` 払い出しの仕組み

サイボウズ社内の kintone を利用し、次の手順で `API Key` を発行できる仕組みを構築しました。ユーザーが行うのはレコード登録のみです（最高！）

1. ユーザーが kintone アプリに `キー名` と `チーム` をレコード登録する  
2. 10 分程度待つ  
3. `API Key` が発行される

![](https://storage.googleapis.com/zenn-user-upload/81e465430f70-20250727.png)

kintone アプリ上では、登録されたチームに所属するメンバーのみ `API Key` を参照できます。

![](https://storage.googleapis.com/zenn-user-upload/2829a343510e-20250727.png)

kintone アプリの情報から LiteLLM の [Key Management API](https://litellm-api.up.railway.app/#/key%20management) を呼び出して `API Key` を発行する処理は Go 言語で実装し、[GitHub Actions の schedule イベント](https://docs.github.com/ja/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule) で定期実行しています。

# あとがき

AI Gateway 基盤構築は [defaultcf](https://zenn.dev/defaultcf) と一緒に実施しました。お互いに一瞬業務ソンから抜けるタイミングもありましたが、「開発者自身が `API Key` を発行できる AI Gateway を構築する」というゴールを達成できました。

今後の展開としては次のようなものを想定しています。
- LLM プロバイダー / モデルを随時新しいものに入れ替える
- `API Key` ごとのトークン利用量を kintone アプリ上で可視化する
- `API Key` ごとでトークン利用量の制限する
- ガードレールを導入する
- Prompt 管理、LLM as a Judge 等の開発支援機能要望に応じて LiteLLM に Langfuse を接続する

結論、業務ソンはいいぞ！
