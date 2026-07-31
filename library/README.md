# 自作 Ruby ライブラリ

`00_core/00_contest_dependencies.rb` は必ず最初に合成され、それ以外の `library/**/*.rb` は相対パスの辞書順で解答へ合成されます。
順序判定には、ファイル名だけでなく `library/` からの相対パス全体を使用します。
ディレクトリをまたぐ依存順がある場合は、`00_core/`、`10_graph/` のようにディレクトリ名にも数値接頭辞を付けてください。
依存関係は自動解析しません。
編集中のファイルを合成対象から外す場合は、拡張子を `.rb.disabled` などへ変更してください。
名前がドットで始まるファイルとディレクトリは合成対象外です。
`library/` 配下では、拡張子にかかわらずシンボリックリンクを使用できません。

ライブラリは `module` または `class` の名前空間へ定義し、ファイルを読み込んだ時点では入出力や自己テストを実行しない構成を推奨します。
標準ライブラリを読み込む `require "set"` などは使用できます。
`00_core/00_contest_dependencies.rb` は最初に読み込まれ、`Set`、`Prime`、`BitUtils`、`SortedContainers` と、そこで個別に読み込む `ac-library-rb` のアルゴリズム群を提供します。
`AcLibraryRb` はトップレベルへ `include` 済みなので、後続の自作ライブラリでも `DSU`、`Segtree`、`PriorityQueue` などを名前空間なしで使用できます。
`ac-library-rb` の `core_ext/all` や `core_ext/integer` は読み込まないため、必要な場合だけ明示的に `require` してください。
用途限定のgemや `make setup-full` 対象の重いgemは必要なファイルで個別に `require` してください。
各ファイルは UTF-8 で保存してください。
`# frozen_string_literal: true` は不要です。
既存ファイルで明示する場合、合成時に解答先頭の1行へまとめられます。
その場合、指定を省略したファイルを含む解答全体へ適用されます。
`true` と `false` は同じ解答内で混在できません。

合成後も同じ意味になるように、次の機能はライブラリ内で使用できません。

- `require_relative`
- `__END__` と `DATA`

`__FILE__` と `__dir__` は合成後のファイルを指します。
ライブラリから別ファイルを参照する実装は避けてください。
refinement の `using` やトップレベルの自己テストも、ファイルを分けて読み込む場合と有効範囲が変わるため使用しないでください。
`if __FILE__ == $PROGRAM_NAME` で囲んだ自己テストも、合成後には実行されます。

`bin/atcoder test`、`run`、`random`、`submit` は、最新のライブラリと `main.rb` を毎回合成して実行します。
`bin/atcoder bundle <TARGET>` は、手動提出用の `submission.rb` を問題ディレクトリへ生成します。
生成済みの `submission.rb` へ直接加えた変更は、次回の `bundle` または `submit` による更新時に失われます。
