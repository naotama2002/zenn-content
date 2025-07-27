---
title: "AI Gateway を AI 開発生産性爆アゲ業務ソンで実装したはなし"
emoji: "⛱️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws", "aigateway", "litellm"]
published: true
published_at: 2025-07-30 00:00 # JST
publication_name: "cybozu_ept"
---

:::message
この記事は、[CYBOZU SUMMER BLOG FES '25](https://cybozu.github.io/summer-blog-fes-2025/)の記事です。
:::

こんにちは、サイボウズ生産性向上チーム + AI やっていきチームの [@naotama](https://x.com/naotama)^[今回の記事は生産性向上チームとしての人格です] です。
今回は、サイボウズ生産性向上チームで 3日間に渡って実施された「AI 開発生産性爆アゲ業務ソン」で AI Gateway を実装した取り組みを紹介したいと思います。

# 背景

サイボウズには AI やっていきという AI 推進チームがあり、組織横断で AI に関連する様々な活動をしています。チーム活動のひとつに「社内の AI 基盤構築」があるのですが、「作りたい基盤はあるが実装できていない」を課題を解決するため、[開発生産性を高めてサイボウズを加速する](https://www.docswell.com/s/cybozu-tech/5R2X3N-engineering-productivity-team-recruitment-information#p3)をミッションを掲げて活動している[生産性向上チーム](https://zenn.dev/p/cybozu_ept)に開発が依頼されました。

スピード感を持って基盤構築をするために「AI 開発生産性爆アゲ業務ソン」と銘打って 2025/07/22 - 24 の3日間、次の 2チームで活動しました。

- リモートコーディングエージェント基盤開発
  - Claude Code Action を AWS 基盤込みでシュッと使える基盤を開発する
- AI Gateway 基盤開発
  - 開発者が LLM モデルを各種プロバイダー契約をなしにシュッと使える基盤を開発する

# モチベーション

開発者・チームが LLM を利用した開発をする際に「 AWS と契約して Bedrock 利用する」までの各種手続きをスキップして、使いたいタイミングで各種プロバイダの LLM モデルを利用可能な状態を提供する！そのために OpenAI API 仕様準拠の AI Gateway を提供する。

# AI Gateway

## 要件

1. OpenAI API 準拠の API を提供する
OpenAI API 仕様で提供すれば各種 LLM ライブラリでほぼサポートされていると思われる

2. 社内で開発者向けに提供する
社内ネットワークに閉じて API を提供する

3. 開発者が利用したいタイミングで利用開始できる（人の手を介さない）環境を提供する
kintone アプリでレコード登録するだけで、`API Key` が自動で払い出される！運用者に負担をかけない

4. メトリクスを提供して運用者が利用状況を把握できるようにする
アクセス状況, LLM モデルの利用状況を可視化する

## Gateway 機能

AI Gateway を実装した経験から、[LiteLLM](https://www.litellm.ai/) の [LiteLLM Proxy Server (LLM Gateway)](https://docs.litellm.ai/docs/simple_proxy) を利用前提としました。

業務ソン前半に Docker を利用して LiteLLM Proxy Server をローカルに構築し要件を満たせるか確認しました。

- OpenAI API 準拠の API を提供できる
- 開発者に `API Key` を払い出すための API を備えている

LiteLLM の SSO 機能を利用すれば開発者自身で `API Key` 払い出し可能ですが、今回は Open Source 版を利用させてもらうため、`API Key` を外部からコントロールする API が充実しており LiteLLM 素晴らしい！となりました。

## メトリクス機能

過去の経験から [Langfuse](https://langfuse.com/) と LiteLLM を連携させてメトリクスを提供することを想定していましたが、今回は LiteLLM が提供するメトリクスで要件を満たせそうということで、Langfuse との連携は見送りました。

入出力ログを確認しながらの Prompt 管理や LLM as a Judge を実施したい等、追加の要望があった際に Langfuse との連携を検討していきたいと思います。

払い出した API key 単位や、チーム単位でのメトリクスが提供されており必要十分です。
![](https://storage.googleapis.com/zenn-user-upload/efaf54a9d0e2-20250727.png)


## インフラ (AWS)

AWS に社内ネットワークに繋がる VPC を用意し ALB + ECS + Autora Serverless for PostgreSQL で LiteLLM をサービスしています。

![](https://storage.googleapis.com/zenn-user-upload/0955cbebca83-20250727.jpg)

コンテナ実行環境には ECS を採用しています。ECS on EC2 ではなく Fargate なのはわたしの趣味です。3日間で構築して稼働スピード感を重視し、わたしが好き＆経験が豊富な ECS Fargate を採用しました。EKS ？はできるだけ避けたい精神の持ち主なので察していただけると幸いです。

インフラは Terraform + ECS Service / Task を [ecspresso](https://github.com/kayac/ecspresso) で管理しています。最近は、Terraform でインフラ構築する際は「インフラ構築終わったら `terraform destroy` でちゃんと壊せること -> `terraform apply` で再構築できること」を確認することを心がけています。

### Terraform + ecspresso

![](https://storage.googleapis.com/zenn-user-upload/99e84781a186-20250727.png)

Terraform は Production, Staging 等環境ごとに作成できる構成にしています。
```shell
$ cd ./terraform/environments/production
$ aws sso login
$ terraform xxx
```

ecspress も Production, Staging 等環境ごとにコントロールできる構成にしています。
```shell
$ cd ./terraform/deploy-ecs/production
$ aws sso login
$ ecspresso xxx
```

ECS Task で扱う環境変数を環境ごとに変更するために `ecs-task-def.jsonnet` を置いて ecspress の [Jsonnet functions](https://github.com/kayac/ecspresso/blob/v2/README.md#jsonnet-functions) を利用しています。


## `API Key` 払い出しの仕組み

サイボウズ社内の kintone を利用して `API Key` 払い出しの仕組みを構築しました。

次の手順で `API Key` が発行されます。ユーザが実施するのはレコード登録のみです（最高！）

1. ユーザは kintone アプリに `キー名`, `チーム` をレコード登録する
2. 10分程度待つ
3. API Key が発行される

![](https://storage.googleapis.com/zenn-user-upload/81e465430f70-20250727.png)

kintone アプリ上は登録されたチームに所属するメンバーのみ `API Key` を参照することが可能です。

![](https://storage.googleapis.com/zenn-user-upload/2829a343510e-20250727.png)

kintone アプリの情報から LiteLLM [key management API](https://litellm-api.up.railway.app/#/key%20management) を利用した `API Key` を発行する仕組みは Go 言語で実装し、[GitHub Action の shedule](https://docs.github.com/ja/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule) 機能を利用して実行しています。

# あとがき

AI Gateway 基盤構築は [defaultcf](https://zenn.dev/defaultcf) と一緒に実施しました。お互いに一瞬？業務ソンから抜けるタイミングもありましたが、「開発者自身が `API Key` 発行可能な AI Gateway を構築する」ゴールが達成できました。

業務ソンはいいぞ！
