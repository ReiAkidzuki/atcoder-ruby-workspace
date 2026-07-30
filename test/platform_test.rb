# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "shellwords"
require "tmpdir"

class PlatformTest < Minitest::Test
  PROJECT_ROOT = Pathname(__dir__).parent
  PLATFORM_HELPER = PROJECT_ROOT.join("bin/platform")

  def test_linux_selects_gnu_time_from_path
    with_fake_command("time", "GNU time 1.9") do |directory, executable|
      stdout, stderr, status = run_selector("Linux", directory)

      assert_predicate status, :success?, stderr
      assert_equal "#{executable}\n", stdout
    end
  end

  def test_macos_selects_gtime_from_path
    with_fake_command("gtime", "GNU time 1.9") do |directory, executable|
      stdout, stderr, status = run_selector("Darwin", directory)

      assert_predicate status, :success?, stderr
      assert_equal "#{executable}\n", stdout
    end
  end

  private

  def with_fake_command(name, version)
    Dir.mktmpdir("atcoder-platform-test-") do |temporary_directory|
      directory = Pathname(temporary_directory)
      executable = directory.join(name)
      executable.write(<<~SH)
        #!/usr/bin/env bash
        printf '%s\\n' #{Shellwords.escape(version)}
      SH
      executable.chmod(0o755)
      yield directory, executable
    end
  end

  def run_selector(os_name, path)
    script = <<~SH
      source #{Shellwords.escape(PLATFORM_HELPER.to_s)}
      ATCODER_OS=#{Shellwords.escape(os_name)} atcoder_gnu_time_command
    SH
    Open3.capture3(
      { "PATH" => "#{path}:/usr/bin:/bin" },
      "/bin/bash",
      "-c",
      script
    )
  end
end
