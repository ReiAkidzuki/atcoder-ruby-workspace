# AtCoder Ruby workspace

[English](README.md) | **日本語**

AtCoder の Ruby 3.4.5（CRuby）環境を対象とした作業環境です。
解答本体と自作ライブラリを分けて管理し、実行時と提出時には単一の Ruby ファイルへ合成します。

## GitHub から使い始める

新しい解答リポジトリを作る場合は、GitHub の「Use this template」から「Create a new repository」を選択します。
テンプレートから作ったリポジトリには独立した履歴が作られるため、元リポジトリへ変更を戻す用途の fork は必要ありません。

同じ解答と自作ライブラリを複数の端末で共有する場合は、テンプレートからリポジトリを一度だけ作り、その同じリポジトリを各端末へ clone します。
Cookie はリポジトリへ保存されないため、提出に使う端末ごとに `make login` を実行してください。

## 開催中コンテストでの生成AI利用

AtCoder の[生成AI対策ルール](https://info.atcoder.jp/entry/llm-rules-ja)は、開催中の ABC、Division を問わない ARC、AGC に、Unrated での参加を含めて適用されます。
過去問の練習には適用されず、AHC には[別のルール](https://info.atcoder.jp/entry/ahc-llm-rules-ja)があります。
ルールは変更されることがあるため、参加前に AtCoder の最新版を確認してください。

対象コンテストの開催中は、ルールで指定された方法による問題文の翻訳を除き、生成AIを使用できません。
解法やコードの生成だけでなく、生成AIによるコード補完、問題文の要約、コンパイルエラーやバグの診断、プログラミング言語の変換も禁止されています。
生成AIを使わない通常の補完は許可されていますが、このワークスペースは誤操作を避けるため、対応する VS Code 機能では生成AIを無効にする設定を常時適用します。

### コンテストロックと自動判定

対象コンテストへ参加する前に、リポジトリ全体のAI支援を手動でロックします。

```sh
make contest-lock CONTEST=abc469
make vscode-safe
```

ロックはリポジトリ直下の `.atcoder-contest-lock` と、端末共通の
`${XDG_STATE_HOME:-$HOME/.local/state}/atcoder-workspace/contest-lock`
へ保存されます。
どちらも Git の追跡対象外で、存在するだけでロックとして扱われます。
内容が壊れていても安全側に停止し、自動では期限切れになりません。
端末共通ロックは、同じ端末の対応済みRuby版・Crystal版workspaceから検出されます。
別の端末には共有されないため、コンテストに使用する端末ごとに実行してください。

ネットワークへ接続せず、現在の手動ロック状態を確認できます。

```sh
make contest-status
```

コンテスト終了を公式ページで確認した後、ユーザー自身がロックを解除します。

```sh
make contest-unlock
```

解除対象は現在のリポジトリのロックと端末共通ロックです。
別のリポジトリでも個別に `make contest-lock` を実行していた場合、その
リポジトリ直下のロックは当該リポジトリで解除してください。

対応するAIエージェントは、コンテストに関係する作業の前に次と同等の確認を自動で実行するよう指示されています。
手動でも状態を確認できます。

```sh
make contest-check CONTEST=abc469
# 対象パスも渡すと、明示IDとメタデータの不一致も検出
bin/contest-guard check --contest abc469 abc469/a
# URL・ワークスペース内の対象パスだけから判定することも可能
bin/contest-guard check abc469/a
```

ガードは対象コンテストの公式トップページと、AtCoder の `/servertime` を毎回取得し、ページ内のコンテストIDと開始・終了時刻を公式サーバー時刻と照合します。
開始直前に作業がまたがることを避けるため開始5分前から停止し、AtCoder の[障害時の延長運用](https://atcoder.jp/posts/1027?lang=ja)がページへ反映されるまでの安全時間として、掲載された終了時刻からさらに20分経過するまで停止します。
開催中、通信失敗、ページ形式の変更、時刻や対象の不一致、判定不能の場合は非ゼロで終了し、AIエージェントを停止させます。
終了前後の自動判定によって、リポジトリまたは端末共通の手動ロックを
作成または削除することはありません。

自動判定はその時点の補助情報であり、公式ページの確認と手動ロックの代わりにはなりません。
自動確認の対象は現在の共通ルールが適用される ABC、ARC、AGC です。
AHC やそれ以外のコンテストは、別のルールを誤って許可しないよう自動では `CLEAR` にしません。
また、この判定は指定された対象だけを確認するため、ユーザーが別の開催中コンテストへ参加しているかは判断できません。
その参加状態を表す主な安全策が手動ロックです。

### VS Code でAI機能を停止する

`.vscode/settings.json` は、VS Code 公式の [`chat.disableAIFeatures`](https://code.visualstudio.com/docs/setup/copilot) と個別の補助設定により、組み込みAI、Copilot、インライン提案をこのワークスペースで無効にします。
対象コンテストへ参加するときは、既存の VS Code ウィンドウを閉じ、次のコマンドで新しいウィンドウを開いてください。

```sh
make vscode-safe
```

このコマンドは [`code --new-window --disable-extensions`](https://code.visualstudio.com/docs/configure/command-line) を使用し、生成AI以外も含むすべての拡張機能をそのウィンドウで停止します。
`AGENTS.md` と `.github/copilot-instructions.md` は、対応するAIエージェントに手動ロックと公式時刻を確認し、開催中または判定不能の問題を扱わないよう指示します。

これらの設定は誤操作を減らすための予防策であり、ルール順守を保証するものではありません。
別のエディタ、VS Code 派生製品、別のウィンドウや既に動作中のツール、ブラウザ、デスクトップアプリ、CLI、対話型AI検索でAIが停止していることまでは保証できません。
指示ファイルに従わないAIツールへ、コンテストガードを技術的に強制することもできません。
コンテスト開始前にAIアプリ、AIを使うCLI、ブラウザのAIチャットを閉じ、使用するすべての環境で生成AIが停止していることを確認してください。
検索結果のAI概要も閲覧しないでください。

## テンプレートの更新を取り込む

GitHub のテンプレートから作ったリポジトリへ、元のテンプレートの更新が自動で入ることはありません。
手元の変更をすべてコミットし、作業ツリーを空にしてから次を実行します。

```sh
make update-template
```

初回は公開元を指す `template` リモートを追加し、以後はそれを再利用します。
公式リポジトリを指す既存の HTTPS または SSH リモートも再利用しますが、別のリポジトリを指すリモートは書き換えずに停止します。
コマンドは `.atcoder-template-version` を基準に未適用のテンプレートコミットだけを取得し、古いものから順に `cherry-pick` します。
解答や自作ライブラリのコミットは保持され、自動では `push` しません。
`.atcoder-template-version` は追従位置を記録する管理ファイルなので、派生リポジトリ側では手動で編集しないでください。

テンプレートと手元の両方で同じファイルを変更していた場合は、上書きせず通常の `cherry-pick` の競合として停止します。
競合箇所を解消して `git add <ファイル>` を実行した後、更新を続けます。

```sh
git cherry-pick --continue
```

更新全体を取り消す場合は、次を実行します。

```sh
git cherry-pick --abort
```

正常に取り込めたら、依存関係と作業環境を検証してから内容を確認し、自分のリポジトリへ `push` します。

```sh
make setup
make doctor
make self-test
git push
```

### 元テンプレートの更新を公開する

この元テンプレートの `main` を更新する場合は、公開する一連の変更の最後のコミットで `.atcoder-template-version` を新しい一意な値へ更新し、一連のコミットをまとめて `push` します。
追従コマンドは、最新コミットでバージョンが更新されていない場合や、過去のバージョン値が再利用されている場合に停止します。

派生リポジトリは公開済みコミットを追従位置の基準にするため、公開後のリリースコミットを `amend` または `force-push` しないでください。

## 導入

この環境は Apple Silicon Mac と Debian / Ubuntu 系の x86_64 Linux に対応しています。
Windows では Ubuntu の WSL を使用してください。

事前に [rbenv](https://github.com/rbenv/rbenv)、[ruby-build](https://github.com/rbenv/ruby-build)、[uv](https://docs.astral.sh/uv/getting-started/installation/) をインストールします。
macOS では Homebrew を使って次のように導入できます。

```sh
brew install rbenv ruby-build uv
rbenv init
```

`rbenv init` の実行後は、表示に従ってターミナルを開き直します。

Debian / Ubuntu 系 Linux では [ruby-build が案内するビルド環境](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment)を準備し、GNU time の `time` パッケージもインストールしてください。
その後、rbenv と uv の公式手順に従って導入し、`rbenv init` を実行します。

リポジトリを clone したら、次のコマンドを実行します。

```sh
make setup
make doctor
make self-test
```

`make setup` は Ruby 3.4.5、通常プロファイルの gem とネイティブライブラリ、online-judge-tools (`oj`)、AtCoder のログイン補助 (`aclogin`) をインストールします。
通常の `make setup` は競技アルゴリズム向けの軽量な10個の gem だけを導入し、数値計算・最適化・機械学習向けの重い gem を省略します。
macOS の通常プロファイルのネイティブ依存関係は `Brewfile.core`、Ruby の依存関係は `Gemfile.lock` に従います。

AtCoder が提供する非標準 gem をすべて使う場合は、完全プロファイルを導入します。

```sh
make setup-full
```

`make setup-full` は完全な `Brewfile` に従い、OpenBLAS、OR-Tools、Polars、Torch などを追加します。
初回はLibTorchの取得とネイティブ拡張のビルドがあるため、完了まで時間がかかります。
ネイティブ拡張のビルドには原則として2並列を指定します。
必要なら `ATCODER_BUILD_JOBS=4 make setup-full` のように変更できますが、`numo-openblas` など一部の gem は独自に利用可能な CPU 数を選びます。
`make doctor` は選択中のプロファイルに合わせて、Ruby、Bundler、固定した gem、ネイティブライブラリ、AtCoder 用コマンドを検査します。
通常プロファイルでは、オプション gem の検査を `skip` として案内します。
すべて `ok` なら、ローカル実行環境の準備は完了です。
`make self-test` は、ネットワークへ接続せず、一時ディレクトリ内でこの作業環境自体の回帰テストを実行します。

## AtCoder Ruby 3.4.5 環境

このリポジトリは、AtCoder の[使用可能言語・ライブラリ一覧](https://img.atcoder.jp/file/language-update/2025-10/language-list.html)と [Ruby 環境の公式設定](https://img.atcoder.jp/file/language-update/2025-10/087-3-3_ruby-3-3-6.toml)を基準にしています。
公式設定 URL のファイル名は旧版由来ですが、設定本文は Ruby 3.4.5 を指定しています。
Ruby 3.4.5 に付属する RubyGems 3.6.9 と Bundler 2.6.9 を使用し、AtCoder が直接指定している次の20個の非標準 gem を `Gemfile` で固定しています。

| gem | バージョン | gem | バージョン |
| --- | --- | --- | --- |
| `ac-library-rb` | 1.2.0 | `bit_utils` | 0.1.2 |
| `bitarray` | 1.3.1 | `fast_trie` | 0.5.1 |
| `faster_prime` | 1.0.2 | `ffi-geos` | 2.5.0 |
| `immutable-ruby` | 0.2.0 | `lightgbm` | 0.4.3 |
| `numo-linalg` | 0.1.7 | `numo-narray` | 0.9.2.1 |
| `numo-openblas` | 0.5.1 | `or-tools` | 0.16.0 |
| `polars-df` | 0.21.1 | `rbtree` | 0.4.6 |
| `rgl` | 0.6.6 | `rumale` | 1.0.0 |
| `sorted_containers` | 1.1.0 | `sorted_set` | 1.0.3 |
| `torch-rb` | 0.21.0 | `z3` | 0.0.20230311 |

インストールプロファイルは次の2段階です。

- 通常の `make setup`：`ac-library-rb`、`bit_utils`、`bitarray`、`fast_trie`、`faster_prime`、`immutable-ruby`、`rbtree`、`rgl`、`sorted_containers`、`sorted_set`
- `make setup-full`：上記に加えて `ffi-geos`、`lightgbm`、`numo-linalg`、`numo-narray`、`numo-openblas`、`or-tools`、`polars-df`、`rumale`、`torch-rb`、`z3`

解答で後者の gem を `require` する場合は、先に `make setup-full` を実行してください。
一度完全プロファイルを導入した後に `make setup` を実行しても、再導入時の長いビルドを避けるため、ダウンロード済みのオプション gem は削除しません。
選択中の検査プロファイルだけが通常へ切り替わります。

ローカル環境をほかのプロジェクトの gem から隔離するため、`make setup` は gem を `.bundle/gems` へインストールします。
この隔離によって Ruby 付属 gem が新しいリリースへ置き換わらないよう、Ruby 3.4.5 の[付属 gem 一覧](https://github.com/ruby/ruby/blob/v3_4_5/gems/bundled_gems)も `Gemfile` で同じバージョンに固定しています。
`Gemfile.lock` は macOS arm64 と Linux x86_64 の両プラットフォームを記録し、チェックサムを含めて依存関係を再現します。

`Brewfile.core` には通常プロファイル用のGNU time、pkg-config、Rustを定義しています。
完全プロファイル用の `Brewfile` は、これらにCMake、GCC、GEOS、LLVM OpenMP、OpenBLAS、Z3を加えます。
Debian / Ubuntu 系 Linuxでも、選択したプロファイルに対応するaptパッケージだけを導入します。
`torch-rb` 0.21.0 に必要な LibTorch 2.8.0 は `make setup-full` のときだけ取得し、固定した SHA-256 と一致することを展開前に検証します。
完全プロファイルをセットアップ済みのリポジトリを移動した場合は、もう一度 `make setup-full` を実行すると Torch と OpenBLAS の拡張を新しい絶対パスに合わせて再ビルドします。

Bundler はローカルの依存関係を固定するためだけに使用します。
`bin/atcoder test`、`run`、`random` は固定した環境で動作しますが、生成される `submission.rb` は `Gemfile` や Bundler を読み込みません。
AtCoder では、提出コードが公式設定どおり通常の `ruby --jit Main.rb` で実行されます。

## ブラウザでのログインと任意の `oj` Cookie

AtCoder は[ソースコード提出への CAPTCHA 導入](https://atcoder.jp/posts/1457?lang=ja)を告知しており、現在の提出フォームは [Cloudflare Turnstile](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/) で保護されています。
検証トークンは実ブラウザ内で生成されるため、この作業環境は生の HTTP リクエストで回避せず、最後の提出操作をブラウザへ引き継ぎます。
`bin/atcoder submit` を実行する前に、普段使っているブラウザで AtCoder にログインしてください。
通常のブラウザ補助付き提出では、`make login` の実行や Cookie のコピーは不要です。

認証付きの読み取り専用 `oj` 操作で独自のセッションが必要な場合だけ、ブラウザの開発者ツールから `REVEL_SESSION` Cookie の値だけをコピーし、次を実行します。

```sh
make login
```

表示されたプロンプトへ Cookie の値を貼り付けます。
Cookie は `oj` のユーザーデータ領域へ保存され、このリポジトリには保存されません。
Cookie の値をソースコード、コミット、チャットへ貼らないでください。
公開タスクの一覧表示、問題作成、サンプル取得、ローカルテストはログインなしで利用できます。
認証を求められてサンプルを取得できない場合は、`make login` を実行してください。
有効な `oj` Cookie があっても、ブラウザの Turnstile 検証トークンを生成できないため、`oj submit` は拒否される場合があります。

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
サブディレクトリも使用できます。
`library/00_core/00_contest_dependencies.rb` は必ず最初に合成し、それ以外の `library/**/*.rb` は相対パスの辞書順で解答へ合成します。
編集中で合成対象から外したいファイルは、拡張子を `.rb.disabled` などへ変更してください。
名前がドットで始まるファイルとディレクトリは合成対象外です。

```text
library/
├── 00_core/
│   ├── 00_contest_dependencies.rb
│   └── input.rb
├── 10_data_structure/
│   └── fenwick_tree.rb
└── 20_graph/
    └── dijkstra.rb
```

上記の共通依存ファイルを除き、順序判定にはファイル名だけでなく `library/` からの相対パス全体を使用します。
ディレクトリをまたぐ依存順がある場合は、上の例のようにディレクトリ名にも数値接頭辞を付けてください。
依存関係は自動解析しません。
トップレベルの名前衝突を避けるため、ライブラリは固有の `module` または `class` 以下へ定義します。
`library/` 配下では、拡張子にかかわらずシンボリックリンクを使用できません。

`test`、`run`、`random`、`submit` は、最新のライブラリと対象の `main.rb` を一時ファイルへ毎回合成します。
既存の `main.rb` は書き換えません。
ランダムテストでは解答側だけへ合成し、生成器と正解器は独立したまま実行します。
提出時は、公式サンプルと手動ケースを含むローカルテストを通した同一ファイルを `submission.rb` へ保存し、ブラウザへ引き継ぎます。
新しい雛形の `main.rb` は、直接実行した場合もプロジェクト直下のライブラリを読み込みます。
現在の雛形を基にしていない `main.rb` は、`ruby` で直接実行するとライブラリを読み込まない場合があります。
`bin/atcoder run` は実行前に必ず合成します。

### ABC・ARC・AGC向けの共通依存

`library/00_core/00_contest_dependencies.rb` は、解答本体とほかの自作ライブラリより先に合成されます。
新しい `main.rb` では、次の機能を追加の `require` なしで使用できます。

- Ruby標準の `Set` と `Prime`
- ビット操作の `BitUtils`
- 順序付きコンテナの `SortedContainers`
- `ac-library-rb` 1.2.0からこのpreludeが選んだ、DSU、Deque、Priority Queue、Fenwick Tree、Segment Tree、Lazy Segment Tree、ModInt、畳み込み、フロー、SCC、2-SAT、文字列アルゴリズムなど

`AcLibraryRb` はトップレベルへ `include` しているため、`AcLibraryRb::DSU` と `DSU` のどちらでも参照できます。
これらはすべて通常の `make setup` で導入済みで、追加セットアップは不要です。
直接 `ruby abc468/a/main.rb` を実行した場合も、`library.rb` がこのworkspaceの隔離されたgem環境を有効にしてから共通依存を読み込みます。
`core_ext/all` や `core_ext/integer` などの任意の便利拡張は読み込まないため、必要な場合だけ明示的に `require` してください。

用途が限定される `rgl`、`immutable-ruby`、`faster_prime` などは必要な解答または自作ライブラリで明示的に `require` してください。
数値計算・最適化・機械学習系のオプションgemは既定では読み込まず、使用する場合だけ先に `make setup-full` を実行します。
ランダムテストのgeneratorとoracleも起動を軽く保つため、この共通依存を自動では読み込みません。

ライブラリ内では標準ライブラリ用の `require "set"` などを使用できます。
`require_relative` は `main.rb` とライブラリのどちらでも、単一ファイル化後の意味が変わるため合成時にエラーとして拒否します。
ライブラリ内の `__END__` と `DATA` も使用できません。
`main.rb` と各ライブラリは UTF-8 で保存してください。
AtCoder は Ruby を [`ruby --jit Main.rb`](https://img.atcoder.jp/file/language-update/2025-10/language-list.html) で実行し、文字列の凍結を強制していないため、雛形もRuby標準の挙動に合わせて `# frozen_string_literal: true` を付けません。
解答やライブラリへこの指定を記述する必要はありません。
既存ファイルが `true` を明示している場合は、合成時に解答全体の指定として先頭へ1回だけまとめ、各ファイルにあった重複行を除きます。
この場合、指定を省略したファイルの文字列リテラルも凍結されます。
`false` の明示はRuby標準の挙動として扱いますが、1つの合成ファイルで両方の意味を維持できないため、`true` と `false` の混在は拒否します。
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
`submit` コマンドも、すべてのローカルテストが成功した後にこのファイルを更新します。
同名の手書きファイルがある場合は、上書きせずエラーで停止します。
生成済みの `submission.rb` へ直接加えた変更は、次回の `bundle` または `submit` による更新時に失われます。
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
テストが成功すると、テスト済みのものと同一のスナップショットを `submission.rb` へ保存し、対応するクリップボードコマンドがあれば内容をコピーして、問題を選択済みの AtCoder 提出画面を開きます。

```sh
bin/atcoder submit abc468/a
```

ブラウザ上で Ruby 3.4.5（言語 ID `6087`）を確認し、`submission.rb` を貼り付けるかアップロードして、人間確認を完了後に「提出」を押してください。
AtCoder の Turnstile 検証トークンはブラウザで生成して送信する必要があるため、このコマンドから直接 POST は行いません。
ブラウザまたはクリップボードのコマンドが利用できない環境では、代わりにファイルパスと提出 URL を表示します。
自動引き継ぎを止める場合は `ATCODER_NO_BROWSER=1` または `ATCODER_NO_CLIPBOARD=1` を設定できます。

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
ライブラリ順序、自動合成、手動 `bundle`、ランダムテスト、ブラウザ提出用スナップショット、コンテストガードのロック・時刻境界・判定不能時の停止、クリップボード・ブラウザへの引き継ぎ、上書き保護、ソース検査、ログインツール検出、OS 別コマンド選択を確認します。
GitHub Actions では、macOS と Ubuntu の両方で同じセルフテストとインストール済みの AtCoder パーサーの互換性検査を実行します。
さらに、手動実行と毎月の定期実行に対応した Ubuntu x86_64 の環境スモークテストで、Ruby の導入、全 gem のネイティブビルド、LibTorch、全20個の非標準 gem の最小動作まで検証します。

## AtCoder との差

- Ruby は AtCoder と同じ 3.4.5 に固定しています。
- 構文確認は `ruby -c`、サンプル実行は `ruby --jit` です。
- AtCoder が直接指定している非標準 gem は同じバージョンに固定しています。
- AtCoder は間接依存 gem のバージョンを公開していません。`Gemfile.lock` は 2025-10 環境の公開時点で互換性のある依存関係を固定していますが、審査環境の間接依存と完全に同じであることまでは保証できません。
- macOS arm64 では Homebrew のネイティブライブラリと macOS 用 LibTorch を使用します。AtCoder の Linux x86_64 環境とは OS、CPU、ネイティブライブラリのビルドが異なるため、実行時間、メモリ使用量、浮動小数点演算の細部は一致しない場合があります。
- AtCoder API クライアントは、`MiB` と `KiB` のメモリ制限に対応したリリースが出るまで、[上流へ提案中のパーサー修正](https://github.com/online-judge-tools/api-client/pull/175)の特定コミットへ固定しています。
- AtCoder は問題のメモリ制限に合わせて `RUBY_THREAD_VM_STACK_SIZE={memory:b}` を設定します。ローカルでは問題ごとの値を自動設定しないため、深い再帰を使う場合は同じ値を明示してください。
- AtCoder にない gem を使った解答は提出先で動きません。標準ライブラリ中心を推奨します。

現行言語環境の詳細は [AtCoder の使用可能言語・ライブラリ一覧](https://img.atcoder.jp/file/language-update/2025-10/language-list.html)を参照してください。

## ライセンス

このプロジェクトは [MIT License](LICENSE) で公開しています。
