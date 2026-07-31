# frozen_string_literal: true

require "rbconfig"

module AtCoderProjectGemEnvironment
  BUNDLER_VERSION = "2.6.9"
  BUNDLER_REQUIREMENT = "= 2.6.9"
  ACTIVATION_MARKER = "ATCODER_PROJECT_GEM_HOME"

  module_function

  def activate!(script, arguments)
    project_root = File.expand_path("..", __dir__)
    gemfile = File.join(project_root, "Gemfile")
    return unless File.file?(gemfile)

    gem_home = File.join(
      project_root,
      ".bundle/gems/ruby",
      RbConfig::CONFIG.fetch("ruby_version")
    )
    return if active?(gem_home)

    unless File.directory?(gem_home)
      abort "error: Ruby gems are not installed; run `make setup`"
    end

    bundle = Gem.bin_path("bundler", "bundle", BUNDLER_REQUIREMENT)
    bundle_environment = {
      ACTIVATION_MARKER => nil,
      "BUNDLE_APP_CONFIG" => nil,
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLE_DISABLE_SHARED_GEMS" => "true",
      "BUNDLE_FROZEN" => "true",
      "BUNDLE_GEMFILE" => gemfile,
      "BUNDLE_IGNORE_CONFIG" => "true",
      "BUNDLE_PATH" => File.join(project_root, ".bundle/gems"),
      "BUNDLE_WITHOUT" => "",
      "GEM_HOME" => nil,
      "GEM_PATH" => nil,
      "RUBYLIB" => nil,
      "RUBYOPT" => nil,
      "RUBYGEMS_GEMDEPS" => nil
    }
    complete = system(
      bundle_environment,
      RbConfig.ruby,
      bundle,
      "check",
      chdir: project_root,
      out: File::NULL,
      err: File::NULL
    )
    unless complete
      abort "error: Ruby gem environment is incomplete; run `make setup`"
    end

    exec(
      {
        ACTIVATION_MARKER => gem_home,
        "BUNDLE_APP_CONFIG" => nil,
        "BUNDLE_BIN_PATH" => nil,
        "BUNDLE_DISABLE_SHARED_GEMS" => nil,
        "BUNDLE_FROZEN" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_IGNORE_CONFIG" => nil,
        "BUNDLE_PATH" => nil,
        "BUNDLE_WITHOUT" => nil,
        "GEM_HOME" => gem_home,
        "GEM_PATH" => gem_home,
        "RUBYLIB" => nil,
        "RUBYOPT" => nil,
        "RUBYGEMS_GEMDEPS" => nil
      },
      RbConfig.ruby,
      File.expand_path(script),
      *arguments
    )
  rescue Gem::GemNotFoundException
    abort "error: Bundler #{BUNDLER_VERSION} is unavailable; run `make setup`"
  end

  def active?(gem_home)
    ENV[ACTIVATION_MARKER] == gem_home &&
      File.expand_path(Gem.dir) == gem_home &&
      Gem.path.map { |path| File.expand_path(path) } == [gem_home]
  end
end
