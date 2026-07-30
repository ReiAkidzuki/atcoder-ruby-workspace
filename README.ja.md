# AtCoder Ruby workspace

[English](README.md) | **日本語**

AtCoder の Ruby 3.4.5（CRuby）環境を対象とした作業環境です。
解答本体と自作ライブラリを分けて管理し、実行時と提出時には単一の Ruby ファイルへ合成します。

## GitHub から使い始める

新しい解答リポジトリを作る場合は、GitHub の「Use this template」から「Create a new repository」を選択します。
テンプレートから作ったリポジトリには独立した履歴が作られるため、元リポジトリへ変更を戻す用途の fork は必要ありません。

同じ解答と自作ライブラリを複数の端末で共有する場合は、テンプレートからリポジトリを一度だけ作り、その同じリポジトリを各端末へ clone します。
Cookie はリポジトリへ保存されないため、提出に使う端末ごとに `make login` を実行してください。

## 導入

この環境は macOS と Linux に対応しています。
Windows では WSL を使用してください。

事前に [rbenv](https://github.com/rbenv/rbenv)、[ruby-build](https://github.com/rbenv/ruby-build)、[uv](https://docs.astral.sh/uv/getting-started/installation/) をインストールします。
macOS では Homebrew を使って次のように導入できます。

```sh
brew install rbenv ruby-build uv
rbenv init
```

`rbenv init` の実行後は、表示に従ってターミナルを開き直します。

Linux では [ruby-build が案内するビルド環境](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment)を準備し、GNU time の `time` パッケージもインストールしてください。
その後、rbenv と uv の公式手順に従って導入し、`rbenv init` を実行します。

リポジトリを clone したら、次のコマンドを実行します。

```sh
make setup
make doctor
make self-test
```

`make setup` は Ruby 3.4.5、online-judge-tools (`oj`)、AtCoder のログイン補助 (`aclogin`) をインストールします。
macOS で GNU time が不足している場合は、Homebrew から併せてインストールします。
`make doctor` がすべて `ok` なら、ローカル実行環境の準備は完了です。
`make self-test` は、ネットワークへ接続せず、一時ディレクトリ内でこの作業環境自体の回帰テストを実行します。

## 提出前の初回ログイン

AtCoder は CAPTCHA を導入しているため、CLI だけでは自動ログインできません。
ブラウザで AtCoder にログインし、開発者ツールから `REVEL_SESSION` Cookie の値をコピーしてから、次を実行してください。

```sh
make login
```

表示されたプロンプトへ Cookie の値を貼り付けます。
Cookie は `oj` のユーザーデータ領域へ保存され、このリポジトリには保存されません。
Cookie の値をソースコード、コミット、チャットへ貼らないでください。
通常、ログインが必要なのは提出時だけです。
公開タスクの一覧表示、問題作成、サンプル取得、ローカルテストはログインなしで利用できます。
認証を求められてサンプルを取得できない場合は、`make login` を実行してください。

## 使い方

コンテストのタスク一覧を表示できます。

```sh
bin/atcoder tasks abc468
```

全問題の `main.rb` とサンプルを一括作成します。

```sh
bin/atcoder contest abc468
```

生成される構成は次のとおりです。

```text
abc468/
├── .contest.json
├── a/
│   ├── .problem-url
│   ├── main.rb
│   └── test/
│       ├── .samples-complete
│       ├── sample-1.in
│       └── sample-1.out
├── b/
└── ...
```

`.samples-complete` はサンプル取得の完了確認に使う自動管理ファイルです。
編集や削除は不要です。

1問だけ作成する場合は、問題 URL、またはコンテスト ID と問題ラベルを指定します。

```sh
bin/atcoder new abc468 a
# 古いコンテストなど、問題 ID が通常と異なる場合は URL を指定
bin/atcoder new https://atcoder.jp/contests/abc001/tasks/abc001_1
```

解答を書いたら、`test` で公式サンプルと手動ケースを検証するか、`run` で手動実行します。
どちらも AtCoder と同じ `ruby --jit` を使用します。

```sh
bin/atcoder test abc468/a
bin/atcoder run abc468/a
bin/atcoder run abc468/a input.txt
```

## 自作ライブラリ

自作ライブラリは `library/` 以下へ `.rb` ファイルとして配置します。
サブディレクトリも使用でき、`library/**/*.rb` を相対パスの辞書順ですべて解答へ合成します。
編集中で合成対象から外したいファイルは、拡張子を `.rb.disabled` などへ変更してください。
名前がドットで始まるファイルとディレクトリは合成対象外です。

```text
library/
├── 00_core/
│   └── union_find.rb
├── 10_data_structure/
│   └── fenwick_tree.rb
└── 20_graph/
    └── dijkstra.rb
```

順序判定には、ファイル名だけでなく `library/` からの相対パス全体を使用します。
ディレクトリをまたぐ依存順がある場合は、上の例のようにディレクトリ名にも数値接頭辞を付けてください。
依存関係は自動解析しません。
トップレベルの名前衝突を避けるため、ライブラリは固有の `module` または `class` 以下へ定義します。
`library/` 配下では、拡張子にかかわらずシンボリックリンクを使用できません。

`test`、`run`、`random`、`submit` は、最新のライブラリと対象の `main.rb` を一時ファイルへ毎回合成します。
既存の `main.rb` は書き換えません。
ランダムテストでは解答側だけへ合成し、生成器と正解器は独立したまま実行します。
提出時は、公式サンプルと手動ケースを含むローカルテストを通した同一の一時ファイルを `oj` が送信します。
新しい雛形の `main.rb` は、直接実行した場合もプロジェクト直下のライブラリを読み込みます。
現在の雛形を基にしていない `main.rb` は、`ruby` で直接実行するとライブラリを読み込まない場合があります。
`bin/atcoder run` は実行前に必ず合成します。

ライブラリ内では標準ライブラリ用の `require "set"` などを使用できます。
`require_relative` は `main.rb` とライブラリのどちらでも、単一ファイル化後の意味が変わるため合成時にエラーとして拒否します。
ライブラリ内の `__END__` と `DATA` も使用できません。
`main.rb` と各ライブラリは UTF-8 で保存し、実行コードより前に `# frozen_string_literal: true` を記述してください。
通常はファイルの先頭行へ記述します。
合成後は解答全体で frozen string literal が有効になります。
`__FILE__` と `__dir__` は合成後のファイルを指すため、ライブラリから外部ファイルを参照する実装は避けてください。
`if __FILE__ == $PROGRAM_NAME` で囲んだ自己テストも合成後には実行されるため、ライブラリ内へ配置しないでください。

`make doctor` は、ライブラリの構文と上記の合成規則も検査します。
エラーの詳細だけを確認する場合は `bin/atcoder check-library` を実行してください。

手動提出用の単一ファイルは、次のコマンドで `abc468/a/submission.rb` へ生成できます。

```sh
bin/atcoder bundle abc468/a
# または
make bundle TARGET=abc468/a
```

`submission.rb` は Git の追跡対象外です。
再実行時は、このコマンドが生成した `submission.rb` だけを更新します。
同名の手書きファイルがある場合は、上書きせずエラーで停止します。
生成済みの `submission.rb` へ直接加えた変更は、次回の `bundle` で失われます。
修正は `main.rb` または `library/` へ加えてください。

配置規則の短い説明は `library/README.md` にも記載しています。

## 手動テストケース

手元の入力ファイルと期待出力ファイルを、通常のテスト対象へ追加できます。
`INPUT` と `EXPECTED` には既存ファイルのパスを指定します。
相対パスは現在のディレクトリを基準に解決し、絶対パスも使用できます。

```sh
bin/atcoder add-case abc468/a custom-1 input.txt expected.txt
```

この例では、`abc468/a/test/custom-1.in` と `custom-1.out` を作成します。
`NAME` は64文字以内とし、先頭には英小文字か数字、それ以降には英小文字、数字、`_`、`-` を使用できます。
公式サンプル用の `sample-<番号>` は指定できません。
既存ファイルは上書きしないため、同じ名前を追加する場合は先に別の名前を選んでください。
公式サンプルの管理ファイル `.samples-complete` は変更しません。

対になる `test/<名前>.in` と `test/<名前>.out` を直接置く方法も利用できます。
`bin/atcoder test` は、公式サンプルと手動ケースをまとめて実行します。

Make から追加する場合は、次のように指定します。

```sh
make add-case TARGET=abc468/a NAME=custom-1 INPUT=input.txt EXPECTED=expected.txt
```

## ランダムテスト

ランダムテストは、同じ入力に対する正解器の出力と `main.rb` の出力を比較します。
最初に問題ごとの生成器と正解器を作成します。

```sh
bin/atcoder init-random abc468/a
```

このコマンドは、次の二つの雛形を作成します。
再実行しても、編集済みのファイルは上書きしません。

- `random/generator.rb`：第1引数で seed を受け取り、生成した入力を標準出力へ書く
- `random/oracle.rb`：生成した入力を標準入力から読み、期待する出力を標準出力へ書く

雛形は未実装のまま終了ステータス `1` を返します。
コメントに沿って両方を実装してから、ランダムテストを実行してください。

```sh
# seed 1 から 1000 件を実行
bin/atcoder random abc468/a 1000 1

# 省略時は seed 1 から 100 件
bin/atcoder random abc468/a
```

同じ操作は Make からも実行できます。

```sh
make init-random TARGET=abc468/a
make random TARGET=abc468/a COUNT=1000 SEED=1
```

不一致や `main.rb` の異常終了が発生すると、入力、期待出力、実際の出力、seed、標準エラーがあればその内容を `random/failures/` 以下へ保存します。
表示された `bin/atcoder random <TARGET> 1 <SEED>` を実行すれば、同じ seed で再現できます。
正解器の結果を確認した後、表示された `add-case` コマンドで通常の回帰テストへ昇格できます。
生成した失敗データは Git の追跡対象外です。

各プロセスの制限時間は既定で 10 秒、出力上限は標準出力と標準エラーのそれぞれで 16 MiB です。
制限時間は `ATCODER_RANDOM_TIMEOUT=3 bin/atcoder random ...` のように秒数を変更できます。
生成器または正解器が異常終了した場合は、解答の誤りと区別するため終了ステータス `2` で停止します。

比較は CRLF と LF の違いだけを吸収し、それ以外は完全一致として扱います。
浮動小数点の誤差、複数の正解、出力専用問題、特殊ジャッジがある問題には、この完全一致比較をそのまま適用できません。

提出時にも、公式サンプルと手動ケースを含むローカルテストが自動で再実行されます。
テストが成功した場合だけ、Ruby 3.4.5（言語 ID `6087`）として提出確認へ進みます。

```sh
bin/atcoder submit abc468/a
```

同じ操作は Make からも実行できます。

```sh
make tasks CONTEST=abc468
make contest CONTEST=abc468
make new CONTEST=abc468 TASK=a
make self-test
make add-case TARGET=abc468/a NAME=custom-1 INPUT=input.txt EXPECTED=expected.txt
make test TARGET=abc468/a
make run TARGET=abc468/a INPUT=input.txt
make bundle TARGET=abc468/a
make init-random TARGET=abc468/a
make random TARGET=abc468/a COUNT=1000 SEED=1
make submit TARGET=abc468/a
```

`atcoder-cli` (`acc`) は使っていませんが、上の `tasks` と `contest` がタスク一覧表示と全問題一括作成を担当します。
CLI はこのリポジトリ内で完結し、Ruby テンプレートのグローバル設定を必要としません。

## 作業環境のセルフテスト

この作業環境を変更した後は、次のコマンドで回帰テストを実行できます。

```sh
make self-test
```

セルフテストは `test/` 以下にあります。
テストでは独立した一時ディレクトリと外部コマンドの代替実装を使うため、問題ファイルを変更せず、ログインやネットワーク接続も必要としません。
ライブラリ順序、自動合成、手動 `bundle`、ランダムテスト、提出スナップショット、上書き保護、ソース検査、ログインツール検出、OS 別コマンド選択を確認します。
GitHub Actions でも macOS と Ubuntu の両方で同じセルフテストを実行します。

## AtCoder との差

- Ruby は AtCoder と同じ 3.4.5 に固定しています。
- 構文確認は `ruby -c`、サンプル実行は `ruby --jit` です。
- AtCoder 本番とローカル環境では、実行時間やメモリ使用量が完全には一致しません。
- 深い再帰を使う場合、必要に応じて問題のメモリ制限に合わせた `RUBY_THREAD_VM_STACK_SIZE` を設定してください。
- AtCoder にない gem を使った解答は提出先で動きません。標準ライブラリ中心を推奨します。

現行言語環境の詳細は [AtCoder の使用可能言語・ライブラリ一覧](https://img.atcoder.jp/file/language-update/2025-10/language-list.html)を参照してください。

## ライセンス

このプロジェクトは [MIT License](LICENSE) で公開しています。
