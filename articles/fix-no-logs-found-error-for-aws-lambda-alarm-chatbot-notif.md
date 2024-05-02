---
title: "AWS Lambda + Alarm + Chatbot 通知時 Show error logs で No logs found を解決"
emoji: "🦁"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws", "sam", "lambda", "chatbot", "cloudwatch"]
published: true
---

# はじめに

やりたいことはこんな感じ。
- [SAM](https://docs.aws.amazon.com/ja_jp/serverless-application-model/latest/developerguide/what-is-sam.html) で Lambda 関数を Deploy
- AWS Lambda 関数を特定 ClouWatch logs 特定ロググループに集約( 今回は `保存期間=30 (RetentionInDays: 30)` を指定ロググループに集約したい )
- AWS Lambda 関数を AWS CloudWatch Alarm で監視、アラートを AWS Chatbot (Slack) へ通知

結果、Slack へ通知されたアラートの `Show error logs`, `Show logs` を押した時 `No logs found` となってうまく動かない → なんでやー。

いろいろ調査した結果「AWS Chatbot アラートに表示される `Show error logs`, `Show logs` は、デフォルトロググループ名決め打ちで実装されてるんじゃない？」の想定が、カックさんの記事のおかげで「そうだね」となりました。

カックさん記事をチームメンバーが発見
https://kakakakakku.hatenablog.com/entry/2024/04/17/091159
> 「便利な Show error logs ボタンと Show logs ボタンは AWS Lambda 関数のデフォルトの Amazon CloudWatch Logs ロググループ /aws/lambda/xxx を前提に作られている点は注意しておくと良いと思う」

カックさんの記事とても助かりました！という内容です。カックさんへの感謝だけだとなんなんで、解決手法も書いておきます。

# 結論

AWS Lambda 関数名と、ロググループ名を一致させると(AWS Chatbot が期待するロググルー名にすると) AWS Chatbot による通知時 `Show error logs`, `Show logs` がうまく動きます。

例えばこんな感じです。
AWS Lambda 関数名: `LambdaSandboxFunction`
AWS CloudWatch Logs ロググループ名: /aws/lambda/`LambdaSandboxFunction`

# 解決方法

## AWS Lambda 関数名とロググループ名を一致させて解決する

:::message
AWS CloudWatch Alarm 周り、AWS Chatbot 周辺はコードとしては省略しています。
AWS Lambda 関数の Deploy は [SAM](https://docs.aws.amazon.com/ja_jp/serverless-application-model/latest/developerguide/what-is-sam.html) を利用しています。
:::

「AWS Lambda 関数のログを `保存期間=30 (RetentionInDays: 30)` を指定ロググループに集約したい」を実現する [SAM](https://docs.aws.amazon.com/ja_jp/serverless-application-model/latest/developerguide/what-is-sam.html) の template.yaml がこんな感じです。
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  SandboxFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: hello-world/
      Handler: app.lambdaHandler
      Runtime: nodejs20.x
      Architectures:
        - x86_64
      LoggingConfig:
        LogGroup: !Ref SandboxFunctionLogGroup
  SandboxFunctionLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: "/aws/lambda/SandboxFunction"
      RetentionInDays: 30
```

この状態だと、AWS Lambda 関数は `SandboxFunction-{ハッシュ値}` のような関数名で登録されます ( AWS Lambda 関数名とロググループ名が異なる )。
AWS Chatbot の `Show error logs`, `Show logs` が AWS Lambda 関数名とロググループ名が一致していることを期待して動いているので、それに合わせてあげます。

AWS::Serverless::Function では `FunctionName` を利用して関数名の指定ができます。
https://docs.aws.amazon.com/ja_jp/serverless-application-model/latest/developerguide/sam-resource-function.html

```yaml diff
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  SandboxFunction:
    Type: AWS::Serverless::Function
    Properties:
+     FunctionName: SandboxFunction
      CodeUri: hello-world/
      Handler: app.lambdaHandler
      Runtime: nodejs20.x
      Architectures:
        - x86_64
      LoggingConfig:
        LogGroup: !Ref SandboxFunctionLogGroup
  SandboxFunctionLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: "/aws/lambda/SandboxFunction"
      RetentionInDays: 30
```

これで `Show error logs`, `Show logs` が期待通りの動作になります。
:::message
異なるアプローチとして、
作成された Lambda 関数名(`SandboxFunction-{ハッシュ値}`)に合わせて CloudWatch Logs ロググループを作成してあげるでも解決できそうではあるが、あまりスマートではないですよねー
:::

## あとがき

カックさんありがとう。
https://kakakakakku.hatenablog.com/entry/2024/04/17/091159
