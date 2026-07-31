# frozen_string_literal: true

require "bundler"
require "minitest/autorun"
require "pathname"

class AtCoderEnvironmentTest < Minitest::Test
  PROJECT_ROOT = Pathname(__dir__).parent
  GEMFILE = PROJECT_ROOT.join("Gemfile")
  LOCKFILE = PROJECT_ROOT.join("Gemfile.lock")
  BREWFILE = PROJECT_ROOT.join("Brewfile")
  SETUP = PROJECT_ROOT.join("bin/setup")
  DOCTOR = PROJECT_ROOT.join("bin/doctor")
  GEM_CHECKER = PROJECT_ROOT.join("bin/check-atcoder-gems")
  GEM_SMOKE_TEST = PROJECT_ROOT.join("bin/smoke-atcoder-gems")
  PROJECT_GEM_ENVIRONMENT = PROJECT_ROOT.join("bin/project_gem_environment.rb")
  ENVIRONMENT_SMOKE_WORKFLOW =
    PROJECT_ROOT.join(".github/workflows/environment-smoke.yml")
  EXPECTED_RUBY_VERSION = "3.4.5"
  EXPECTED_RUBYGEMS_VERSION = "3.6.9"
  EXPECTED_BUNDLER_VERSION = "2.6.9"
  EXPECTED_GEMS = {
    "ac-library-rb" => "1.2.0",
    "bit_utils" => "0.1.2",
    "bitarray" => "1.3.1",
    "fast_trie" => "0.5.1",
    "faster_prime" => "1.0.2",
    "ffi-geos" => "2.5.0",
    "immutable-ruby" => "0.2.0",
    "lightgbm" => "0.4.3",
    "numo-linalg" => "0.1.7",
    "numo-narray" => "0.9.2.1",
    "numo-openblas" => "0.5.1",
    "or-tools" => "0.16.0",
    "polars-df" => "0.21.1",
    "rbtree" => "0.4.6",
    "rgl" => "0.6.6",
    "rumale" => "1.0.0",
    "sorted_containers" => "1.1.0",
    "sorted_set" => "1.0.3",
    "torch-rb" => "0.21.0",
    "z3" => "0.0.20230311"
  }.freeze
  RUBY_DISTRIBUTED_TRANSITIVE_GEMS = {
    "bigdecimal" => "3.1.8",
    "csv" => "3.3.2",
    "forwardable" => "1.3.3",
    "prime" => "0.1.3",
    "rexml" => "3.4.0",
    "set" => "1.1.1",
    "singleton" => "0.3.0"
  }.freeze
  ATCODER_SNAPSHOT_TRANSITIVE_GEMS = {
    "backports" => "3.25.2",
    "concurrent-ruby" => "1.3.5",
    "ffi" => "1.17.2",
    "function_module" => "0.1.1",
    "lbfgsb" => "0.6.0",
    "mmh3" => "1.2.0",
    "pairing_heap" => "3.1.0",
    "rice" => "4.6.1",
    "stream" => "0.5.5"
  }.freeze
  RUBY_BUNDLED_GEMS = {
    "abbrev" => "0.1.2",
    "base64" => "0.2.0",
    "bigdecimal" => "3.1.8",
    "csv" => "3.3.2",
    "debug" => "1.11.0",
    "drb" => "2.2.1",
    "getoptlong" => "0.2.1",
    "matrix" => "0.4.2",
    "minitest" => "5.25.4",
    "mutex_m" => "0.3.0",
    "net-ftp" => "0.3.8",
    "net-imap" => "0.5.8",
    "net-pop" => "0.1.2",
    "net-smtp" => "0.5.1",
    "nkf" => "0.2.0",
    "observer" => "0.1.2",
    "power_assert" => "2.0.5",
    "prime" => "0.1.3",
    "racc" => "1.8.1",
    "rake" => "13.2.1",
    "rbs" => "3.8.0",
    "repl_type_completor" => "0.1.9",
    "resolv-replace" => "0.1.1",
    "rexml" => "3.4.0",
    "rinda" => "0.2.0",
    "rss" => "0.3.1",
    "syslog" => "0.2.0",
    "test-unit" => "3.6.7",
    "typeprof" => "0.30.1"
  }.freeze
  EXPECTED_BREW_FORMULAE = %w[
    cmake
    gcc
    geos
    gnu-time
    libomp
    openblas
    pkgconf
    rust
    z3
  ].freeze

  def test_ruby_toolchain_matches_atcoder
    assert_equal EXPECTED_RUBY_VERSION, PROJECT_ROOT.join(".ruby-version").read.strip
    assert_equal EXPECTED_RUBY_VERSION, RUBY_VERSION
    assert_equal EXPECTED_RUBYGEMS_VERSION, Gem::VERSION
    assert_equal EXPECTED_BUNDLER_VERSION, Bundler::VERSION
  end

  def test_gemfile_exactly_pins_atcoder_direct_gems
    dsl = Bundler::Dsl.evaluate(GEMFILE.to_s, nil, {})
    atcoder_dependencies = dsl.dependencies.select do |dependency|
      dependency.groups.include?(:atcoder)
    end
    dependencies = atcoder_dependencies.to_h do |dependency|
      [dependency.name, dependency.requirement.to_s.delete_prefix("= ")]
    end

    assert_equal EXPECTED_GEMS, dependencies
    assert atcoder_dependencies.all? { |dependency| dependency.requirement.exact? }
  end

  def test_gemfile_pins_every_gem_bundled_with_ruby_3_4_5
    dsl = Bundler::Dsl.evaluate(GEMFILE.to_s, nil, {})
    bundled_dependencies = dsl.dependencies.select do |dependency|
      dependency.groups.include?(:ruby_bundled)
    end
    dependencies = bundled_dependencies.to_h do |dependency|
      [dependency.name, dependency.requirement.to_s.delete_prefix("= ")]
    end

    assert_equal RUBY_BUNDLED_GEMS, dependencies
  end

  def test_lockfile_covers_atcoder_linux_and_local_macos
    parser = Bundler::LockfileParser.new(LOCKFILE.read)
    platforms = parser.platforms.map(&:to_s)

    assert_equal EXPECTED_BUNDLER_VERSION, parser.bundler_version.to_s
    assert_includes platforms, "arm64-darwin"
    assert_includes platforms, "x86_64-linux"
    assert_includes LOCKFILE.read, "\nCHECKSUMS\n"
  end

  def test_lockfile_does_not_upgrade_ruby_distributed_dependencies
    parser = Bundler::LockfileParser.new(LOCKFILE.read)
    locked_versions = parser.specs.to_h { |spec| [spec.name, spec.version.to_s] }

    RUBY_DISTRIBUTED_TRANSITIVE_GEMS.each do |name, version|
      assert_equal version, locked_versions.fetch(name)
    end
  end

  def test_lockfile_keeps_default_gems_at_ruby_3_4_5_versions
    parser = Bundler::LockfileParser.new(LOCKFILE.read)
    default_versions = Gem::Specification.default_stubs.to_h do |specification|
      [specification.name, specification.version.to_s]
    end

    parser.specs.each do |specification|
      next unless default_versions.key?(specification.name)

      assert_equal default_versions.fetch(specification.name),
        specification.version.to_s,
        "#{specification.name} must match the version shipped with Ruby"
    end
  end

  def test_lockfile_uses_transitives_available_for_the_2025_10_update
    parser = Bundler::LockfileParser.new(LOCKFILE.read)
    locked_versions = parser.specs.to_h { |spec| [spec.name, spec.version.to_s] }

    ATCODER_SNAPSHOT_TRANSITIVE_GEMS.each do |name, version|
      assert_equal version, locked_versions.fetch(name)
    end
  end

  def test_brewfile_declares_native_gem_dependencies
    formulae = BREWFILE.read.scan(/^brew "([^"]+)"$/).flatten

    assert_equal EXPECTED_BREW_FORMULAE, formulae
  end

  def test_setup_installs_native_dependencies_libtorch_and_locked_gems
    source = SETUP.read

    assert_includes source,
      'brew bundle --no-upgrade --file="$project_root/Brewfile"'
    assert_includes source, 'libtorch_url="$(atcoder_libtorch_url)"'
    assert_includes source, 'libtorch_sha256="$(atcoder_libtorch_sha256)"'
    assert_includes source, "SHA-256 mismatch"
    assert_includes source, "include/torch/extension.h"
    assert_includes source, "build.torch-rb"
    assert_includes source, "atcoder_workspace_moved"
    assert_includes source, 'workspace_marker="$project_root/.bundle/workspace-path"'
    assert_includes source,
      '"${bundle_command[@]}" pristine numo-openblas torch-rb'
    assert_includes source, 'build_jobs="${ATCODER_BUILD_JOBS:-2}"'
    assert_includes source, 'bundle_command=(rbenv exec bundle _2.6.9_)'
    assert_includes source, '"${bundle_command[@]}" install --jobs 1'
    assert_includes source, "BUNDLE_FROZEN=true"
    assert_includes source, 'path "$project_root/.bundle/gems"'
    refute_includes source, "path.system"
  end

  def test_doctor_checks_locked_and_plain_ruby_gem_environments
    source = DOCTOR.read
    checker_source = GEM_CHECKER.read

    assert_includes source, 'expected_rubygems="3.6.9"'
    assert_includes source, 'expected_bundler="2.6.9"'
    assert_includes source, 'bundle_command=(rbenv exec bundle _2.6.9_)'
    assert_includes source, 'check "Locked Ruby gems"'
    assert_includes source, 'check "AtCoder gem versions"'
    assert_includes source, 'GEM_HOME="$gem_home"'
    assert_includes source, 'GEM_PATH="$gem_home"'
    assert_includes source, "-u RUBYGEMS_GEMDEPS"
    assert_includes source, '"$project_root/bin/check-atcoder-gems"'
    assert_includes checker_source, "find_all_by_name"
    assert_includes checker_source, "ruby_bundled"
    assert_includes checker_source, "ruby_default_dependencies"
    assert_includes checker_source,
      'require_relative "project_gem_environment"'
    refute_includes checker_source, "ruby_distribution"
    assert_predicate GEM_CHECKER, :executable?
  end

  def test_native_smoke_test_covers_every_atcoder_gem
    source = GEM_SMOKE_TEST.read
    covered_gems = source.scan(/^  "([^"]+)" =>/).flatten

    assert_equal EXPECTED_GEMS.keys.sort, covered_gems.sort
    assert_includes DOCTOR.read, 'check "AtCoder gem smoke tests"'
    assert_includes source, 'require_relative "project_gem_environment"'
    assert_predicate GEM_SMOKE_TEST, :executable?
  end

  def test_project_gem_bootstrap_is_shared_by_all_ruby_commands
    source = PROJECT_GEM_ENVIRONMENT.read

    assert_includes source, 'BUNDLER_REQUIREMENT = "= 2.6.9"'
    assert_includes source, "BUNDLE_FROZEN"
    assert_includes source, "bundle"
    assert_includes source, "exec("
  end

  def test_linux_environment_is_built_and_smoke_tested_in_ci
    source = ENVIRONMENT_SMOKE_WORKFLOW.read

    assert_includes source, "workflow_dispatch:"
    assert_includes source, "schedule:"
    assert_includes source, "runs-on: ubuntu-24.04"
    assert_includes source, "actions/cache@v5"
    assert_includes source, 'mkdir -p "$RBENV_ROOT/plugins"'
    assert_includes source, "./bin/setup"
    assert_includes source, "make self-test"
  end
end
