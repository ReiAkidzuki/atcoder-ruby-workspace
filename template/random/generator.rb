# frozen_string_literal: true

def main
  seed = Integer(ARGV.fetch(0))
  random = Random.new(seed)

  # `random` を使ってテスト入力を標準出力へ書いてください。
  # 例:
  # n = random.rand(1..10)
  # puts n

  warn "TODO: random/generator.rb に入力生成処理を書いてください (seed=#{random.seed})"
  exit 1
end

main
