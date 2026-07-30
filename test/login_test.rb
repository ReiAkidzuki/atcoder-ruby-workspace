# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class LoginTest < Minitest::Test
  PROJECT_ROOT = Pathname(__dir__).parent

  def test_make_login_exposes_the_workspace_virtualenv_to_aclogin
    Dir.mktmpdir("atcoder login test-") do |directory|
      workspace = Pathname(directory)
      FileUtils.cp(PROJECT_ROOT.join("Makefile"), workspace.join("Makefile"))

      virtualenv_bin = workspace.join(".venv/bin")
      virtualenv_bin.mkpath
      write_executable(virtualenv_bin.join("oj"), <<~SH)
        #!/bin/sh
        exit 0
      SH
      write_executable(virtualenv_bin.join("aclogin"), <<~'SH')
        #!/bin/sh
        set -eu

        expected="$PWD/.venv/bin/oj"
        actual="$(command -v oj)"
        test "$actual" = "$expected"
      SH

      _stdout, stderr, status = Open3.capture3(
        { "PATH" => ENV.fetch("PATH") },
        "make",
        "login",
        chdir: workspace.to_s
      )

      assert_predicate status, :success?, stderr
    end
  end

  private

  def write_executable(path, source)
    path.write(source)
    path.chmod(0o755)
  end
end
