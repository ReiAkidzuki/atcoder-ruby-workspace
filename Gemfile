source "https://rubygems.org"

ruby file: ".ruby-version"

# Direct gems installed in AtCoder's Ruby 3.4.5 environment.
# Source: https://img.atcoder.jp/file/language-update/2025-10/087-3-3_ruby-3-3-6.toml
group :atcoder do
  gem "ac-library-rb", "= 1.2.0", require: false
  gem "bit_utils", "= 0.1.2", require: false
  gem "bitarray", "= 1.3.1", require: false
  gem "fast_trie", "= 0.5.1", require: false
  gem "faster_prime", "= 1.0.2", require: false
  gem "immutable-ruby", "= 0.2.0", require: false
  gem "rbtree", "= 0.4.6", require: false
  gem "rgl", "= 0.6.6", require: false
  gem "sorted_containers", "= 1.1.0", require: false
  gem "sorted_set", "= 1.0.3", require: false
end

# Large numerical, optimization, data-processing, and machine-learning gems.
# `make setup-full` installs this group; the default setup skips it.
group :atcoder_optional, optional: true do
  gem "ffi-geos", "= 2.5.0", require: false
  gem "lightgbm", "= 0.4.3", require: false
  gem "numo-linalg", "= 0.1.7", require: false
  gem "numo-narray", "= 0.9.2.1", require: false
  gem "numo-openblas", "= 0.5.1", require: false
  gem "or-tools", "= 0.16.0", require: false
  gem "polars-df", "= 0.21.1", require: false
  gem "rumale", "= 1.0.0", require: false
  gem "torch-rb", "= 0.21.0", require: false
  gem "z3", "= 0.0.20230311", require: false
end

# Ruby 3.4.5 installs these bundled gems together with the interpreter. They
# must be declared as well when the solution is run under an isolated Bundle;
# otherwise Bundler hides bundled libraries such as csv, matrix, and prime.
# Source: https://github.com/ruby/ruby/blob/v3_4_5/gems/bundled_gems
group :ruby_bundled do
  gem "abbrev", "= 0.1.2", require: false
  gem "base64", "= 0.2.0", require: false
  gem "bigdecimal", "= 3.1.8", require: false
  gem "csv", "= 3.3.2", require: false
  gem "debug", "= 1.11.0", require: false
  gem "drb", "= 2.2.1", require: false
  gem "getoptlong", "= 0.2.1", require: false
  gem "matrix", "= 0.4.2", require: false
  gem "minitest", "= 5.25.4", require: false
  gem "mutex_m", "= 0.3.0", require: false
  gem "net-ftp", "= 0.3.8", require: false
  gem "net-imap", "= 0.5.8", require: false
  gem "net-pop", "= 0.1.2", require: false
  gem "net-smtp", "= 0.5.1", require: false
  gem "nkf", "= 0.2.0", require: false
  gem "observer", "= 0.1.2", require: false
  gem "power_assert", "= 2.0.5", require: false
  gem "prime", "= 0.1.3", require: false
  gem "racc", "= 1.8.1", require: false
  gem "rake", "= 13.2.1", require: false
  gem "rbs", "= 3.8.0", require: false
  gem "repl_type_completor", "= 0.1.9", require: false
  gem "resolv-replace", "= 0.1.1", require: false
  gem "rexml", "= 3.4.0", require: false
  gem "rinda", "= 0.2.0", require: false
  gem "rss", "= 0.3.1", require: false
  gem "syslog", "= 0.2.0", require: false
  gem "test-unit", "= 3.6.7", require: false
  gem "typeprof", "= 0.30.1", require: false
end

# These default gems are dependencies of the bundled gems above. Pinning the
# versions shipped with Ruby prevents a later release from entering the lock.
group :ruby_default_dependencies do
  gem "cgi", "= 0.4.2", require: false
  gem "date", "= 3.4.1", require: false
  gem "erb", "= 4.0.4", require: false
  gem "forwardable", "= 1.3.3", require: false
  gem "io-console", "= 0.8.1", require: false
  gem "ipaddr", "= 1.2.7", require: false
  gem "irb", "= 1.14.3", require: false
  gem "logger", "= 1.6.4", require: false
  gem "net-protocol", "= 0.2.2", require: false
  gem "pp", "= 0.6.2", require: false
  gem "prettyprint", "= 0.2.0", require: false
  gem "prism", "= 1.2.0", require: false
  gem "psych", "= 5.2.2", require: false
  gem "rdoc", "= 6.14.0", require: false
  gem "reline", "= 0.6.0", require: false
  gem "resolv", "= 0.6.2", require: false
  gem "set", "= 1.1.1", require: false
  gem "singleton", "= 0.3.0", require: false
  gem "stringio", "= 3.1.2", require: false
  gem "time", "= 0.4.1", require: false
  gem "timeout", "= 0.4.3", require: false
  gem "tsort", "= 0.2.0", require: false
end

# AtCoder does not publish versions for indirect gems. These are the newest
# compatible releases available by the end of the named 2025-10 judge update.
# Keeping this snapshot avoids resolving newer, incompatible APIs such as
# Rice 4.7+ with the official or-tools and torch-rb releases.
group :atcoder_snapshot do
  gem "backports", "= 3.25.2", require: false
  gem "concurrent-ruby", "= 1.3.5", require: false
  gem "function_module", "= 0.1.1", require: false
  gem "pairing_heap", "= 3.1.0", require: false
  gem "stream", "= 0.5.5", require: false
end

# Snapshot pins used exclusively by the optional AtCoder gems. Keeping them in
# the skipped group prevents native dependencies from leaking into core setup.
group :atcoder_optional_snapshot, optional: true do
  gem "ffi", "= 1.17.2", require: false
  gem "lbfgsb", "= 0.6.0", require: false
  gem "mmh3", "= 1.2.0", require: false
  gem "rice", "= 4.6.1", require: false
end
