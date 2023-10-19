---
title: "変更のない Terraform plan 結果を tfcmt が Pull Request に貼るのをスキップしたい"
emoji: "🐶"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["githubactions", "terraform", "#tfcmt"]
published: true
---

# 実現したいこと

GitHub Actions workflow で [tfcmt](https://github.com/suzuki-shunsuke/tfcmt) を利用して Pull Request 時に Terraform plan 結果を貼っている。

複数 Terraform plan の実行結果、"No changes" の結果も貼られ冗長なため、"No changes" の結果は、Pull Request コメントに貼られないように(SKIP) したい。

# 改善したい状況 (No changes の Terraform plan 結果が貼られている状態)

[このリポジトリ](https://github.com/naotama2002/sample-tfcmt-skip-no-changes/blob/main/.github/workflows/tfcmt.yaml)では、の 4 つの Terraform plan 結果を tfcmt を利用して確認している。
- staging-prepear
- staging
- production-prepear
- production


tfcmt の結果は下記のように、"No changes" の plan 結果も Pull Request コメントに貼られ、冗長な状態。

### [Pull Request](https://github.com/naotama2002/sample-tfcmt-skip-no-changes/pull/3) の結果表示(冗長)

![Pull Request の結果に No changes の plan 結果が貼られている](https://storage.googleapis.com/zenn-user-upload/f8243fd56006-20230819.png)

# 改善された状況 (No changes の Terraform plan 結果がスキップされた状態)

## tfcmt v4.4.0 で --skip-no-changes が実装された🎉　これを利用して "No changes" の plan 結果が貼られないに変更

:::message
[tfcmt v4.4.0 で --skip-no-changes が実装された](https://github.com/suzuki-shunsuke/tfcmt/releases/tag/v4.4.0)
:::

[こんな感じで、--skip-no-changes を指定](https://github.com/naotama2002/sample-tfcmt-skip-no-changes/pull/4)します。
```hcl diff
- run: tfcmt --var target:${{ matrix.directory }} plan --patch -- terraform plan -no-color -input=false
+ run: tfcmt --var target:${{ matrix.directory }} plan --patch --skip-no-changes -- terraform plan -no-color -input=false
```

## --skip-no-changes を指定した [Pull Request]((https://github.com/naotama2002/sample-tfcmt-skip-no-changes/pull/4)) 結果

staging-prepear, staging, production-prepear が no-change だったことは、ラベルでわかるし、No changes の結果が貼られてなくてスッキリしました🎉 キャプチャの縦長に注目。

![--skip-no-changes を指定した Pull Request 結果](https://storage.googleapis.com/zenn-user-upload/b57b149d7239-20230819.png)

# 最後に

今回の記事の実験リポジトリはこちら : https://github.com/naotama2002/sample-tfcmt-skip-no-changes



## リンク

- tfcmt : https://github.com/suzuki-shunsuke/tfcmt
