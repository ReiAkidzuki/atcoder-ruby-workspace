# frozen_string_literal: true

require "rbconfig"

module AtCoderProjectGemEnvironment
  BUNDLER_VERSION = "2.6.9"
  BUNDLER_REQUIREMENT = "= 2.6.9"
  ACTIVATION_MARKER = "ATCODER_PROJECT_GEM_HOME"
  PROFILE_MARKER = ".bundle/atcoder-gem-profile"
  CORE_PROFILE = "core"
  FULL_PROFILE = "full"
  OPTIONAL_GROUPS = "atcoder_optional:atcoder_optional_snapshot"

  module_function

  def activate!(script, arguments)
    activation = pending_activation
    return unless activation

    ruby_arguments = []
    if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
      ruby_arguments << "--yjit"
    end
    exec(
      activation.fetch(:environment),
      RbConfig.ruby,
      *ruby_arguments,
      File.expand_path(script),
      *arguments
    )
  end

  def activate_in_process!
    activation = pending_activation
    return unless activation

    activation.fetch(:environment).each do |name, value|
      if value.nil?
        ENV.delete(name)
      else
        ENV[name] = value
      end
    end
    gem_home = activation.fetch(:gem_home)
    Gem.use_paths(gem_home, [gem_home])
  end

  def pending_activation
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

    setup_target =
      if profile(project_root) == FULL_PROFILE
        "make setup-full"
      else
        "make setup"
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
      "BUNDLE_ONLY" => "",
      "BUNDLE_PATH" => File.join(project_root, ".bundle/gems"),
      "BUNDLE_WITH" => bundle_with(project_root),
      "BUNDLE_WITHOUT" => bundle_without(project_root),
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
      abort "error: Ruby gem environment is incomplete; run `#{setup_target}`"
    end

    {
      gem_home:,
      environment: {
        ACTIVATION_MARKER => gem_home,
        "BUNDLE_APP_CONFIG" => nil,
        "BUNDLE_BIN_PATH" => nil,
        "BUNDLE_DISABLE_SHARED_GEMS" => nil,
        "BUNDLE_FROZEN" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_IGNORE_CONFIG" => nil,
        "BUNDLE_ONLY" => nil,
        "BUNDLE_PATH" => nil,
        "BUNDLE_WITH" => nil,
        "BUNDLE_WITHOUT" => nil,
        "GEM_HOME" => gem_home,
        "GEM_PATH" => gem_home,
        "RUBYLIB" => nil,
        "RUBYOPT" => nil,
        "RUBYGEMS_GEMDEPS" => nil
      }
    }
  rescue ArgumentError => error
    abort "error: #{error.message}"
  rescue Gem::GemNotFoundException
    abort "error: Bundler #{BUNDLER_VERSION} is unavailable; run `make setup`"
  end

  def active?(gem_home)
    ENV[ACTIVATION_MARKER] == gem_home &&
      File.expand_path(Gem.dir) == gem_home &&
      Gem.path.map { |path| File.expand_path(path) } == [gem_home]
  end

  def profile(project_root)
    marker = File.join(File.expand_path(project_root), PROFILE_MARKER)
    return FULL_PROFILE unless File.file?(marker)

    value = File.read(marker).strip
    return value if [CORE_PROFILE, FULL_PROFILE].include?(value)

    raise ArgumentError,
      "invalid AtCoder gem profile #{value.inspect} in #{marker}"
  end

  def bundle_without(project_root)
    profile(project_root) == CORE_PROFILE ? OPTIONAL_GROUPS : ""
  end

  def bundle_with(project_root)
    profile(project_root) == FULL_PROFILE ? OPTIONAL_GROUPS : ""
  end
end
