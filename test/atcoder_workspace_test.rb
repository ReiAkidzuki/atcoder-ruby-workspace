# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

class AtCoderWorkspaceTest < Minitest::Test
  PROJECT_ROOT = Pathname(__dir__).parent

  def setup
    @sandbox = Pathname(Dir.mktmpdir("atcoder-workspace-test-"))
    @sandbox.join("bin").mkpath
    @sandbox.join("library").mkpath
    @problem = @sandbox.join("contest/a")
    @problem.mkpath
    FileUtils.cp(PROJECT_ROOT.join("bin/atcoder"), @sandbox.join("bin/atcoder"))
  end

  def teardown
    FileUtils.remove_entry(@sandbox) if @sandbox&.directory?
  end

  def test_bundle_preserves_main_data_section_exactly
    payload = "first line\n# data comment\nlast line"
    write_main(<<~RUBY.chomp)
      # frozen_string_literal: true

      print DATA.read
      __END__
      #{payload}
    RUBY

    _stdout, stderr, status = atcoder("bundle", "contest/a")

    assert_predicate status, :success?, stderr
    stdout, run_stderr, run_status = ruby(@problem.join("submission.rb"))
    assert_predicate run_status, :success?, run_stderr
    assert_equal payload, stdout
  end

  def test_bundle_rejects_hyphenated_frozen_string_literal_false
    write_main(<<~RUBY)
      # -*- frozen-string-literal: false -*-

      puts "mutable"
    RUBY

    _stdout, stderr, status = atcoder("bundle", "contest/a")

    refute_predicate status, :success?
    assert_includes stderr, "frozen_string_literal: false cannot be bundled"
  end

  def test_library_allows_end_marker_text_inside_heredoc
    write_library("text.rb", <<~RUBY)
      # frozen_string_literal: true

      TEXT_FROM_LIBRARY = <<~TEXT
      __END__
      TEXT
    RUBY
    write_main(<<~RUBY)
      # frozen_string_literal: true

      print TEXT_FROM_LIBRARY
    RUBY

    _stdout, stderr, status = atcoder("bundle", "contest/a")

    assert_predicate status, :success?, stderr
    stdout, run_stderr, run_status = ruby(@problem.join("submission.rb"))
    assert_predicate run_status, :success?, run_stderr
    assert_equal "__END__\n", stdout
  end

  def test_library_magic_comment_after_code_is_not_a_declaration
    write_library("value.rb", <<~RUBY)
      VALUE_FROM_LIBRARY = "mutable"
      # frozen_string_literal: true
    RUBY
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts VALUE_FROM_LIBRARY
    RUBY

    _stdout, stderr, status = atcoder("check-library")

    refute_predicate status, :success?
    assert_includes stderr, "must declare frozen_string_literal: true"
  end

  def test_main_requires_frozen_string_literal_declaration
    write_main("puts \"missing declaration\"\n")

    _stdout, stderr, status = atcoder("bundle", "contest/a")

    refute_predicate status, :success?
    assert_includes stderr, "must declare frozen_string_literal: true"
  end

  def test_bundle_orders_nested_libraries_before_main_and_is_executable
    write_library("10_extension/value.rb", <<~RUBY)
      # frozen_string_literal: true

      BUNDLE_ORDER << "extension"
    RUBY
    write_library("00_core.rb", <<~RUBY)
      # frozen_string_literal: true

      BUNDLE_ORDER = ["core"]
    RUBY
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts BUNDLE_ORDER.join(",")
    RUBY

    stdout, stderr, status = atcoder("bundle", "contest/a")

    assert_predicate status, :success?, stderr
    assert_includes stdout, "2 library files"
    submission = @problem.join("submission.rb")
    source = submission.binread
    assert_operator source.index("library/00_core.rb"), :<, source.index("library/10_extension/value.rb")
    assert_operator source.index("library/10_extension/value.rb"), :<, source.index("contest/a/main.rb")
    assert_equal 0o644, submission.stat.mode & 0o777
    run_stdout, run_stderr, run_status = ruby(submission)
    assert_predicate run_status, :success?, run_stderr
    assert_equal "core,extension\n", run_stdout
  end

  def test_run_uses_the_latest_library_without_rewriting_main
    write_library_value(3)
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts LibraryValue::VALUE
    RUBY
    original_main = @problem.join("main.rb").binread

    stdout, stderr, status = atcoder("run", "contest/a")

    assert_predicate status, :success?, stderr
    assert_equal "3", stdout.lines(chomp: true).last

    write_library_value(8)
    updated_stdout, updated_stderr, updated_status = atcoder("run", "contest/a")

    assert_predicate updated_status, :success?, updated_stderr
    assert_equal "8", updated_stdout.lines(chomp: true).last
    assert_equal original_main, @problem.join("main.rb").binread
    assert_empty temporary_bundles
  end

  def test_random_bundles_only_the_candidate
    write_library("offset.rb", <<~RUBY)
      # frozen_string_literal: true

      module RandomOffset
        VALUE = 7
      end
    RUBY
    write_main(<<~RUBY)
      # frozen_string_literal: true

      value = Integer($stdin.read)
      puts value + RandomOffset::VALUE
    RUBY
    write_problem_file("random/generator.rb", <<~RUBY)
      # frozen_string_literal: true

      abort "library leaked into generator" if defined?(RandomOffset)
      puts Integer(ARGV.fetch(0))
    RUBY
    write_problem_file("random/oracle.rb", <<~RUBY)
      # frozen_string_literal: true

      abort "library leaked into oracle" if defined?(RandomOffset)
      puts Integer($stdin.read) + 7
    RUBY

    stdout, stderr, status = atcoder("random", "contest/a", "3", "5")

    assert_predicate status, :success?, stderr
    assert_includes stdout, "PASS: 3 random cases"
    assert_empty temporary_bundles
  end

  def test_submit_tests_and_prepares_the_same_snapshot_for_browser
    log = @sandbox.join("oj.log")
    install_fake_oj
    write_library("offset.rb", <<~RUBY)
      # frozen_string_literal: true

      SUBMIT_OFFSET = 4
    RUBY
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts Integer($stdin.read) + SUBMIT_OFFSET
    RUBY
    write_problem_file("test/sample-1.in", "3\n")
    write_problem_file("test/sample-1.out", "7\n")
    write_problem_file(
      ".problem-url",
      "https://atcoder.jp/contests/abc999/tasks/abc999_a\n"
    )

    stdout, stderr, status = atcoder(
      "submit",
      "contest/a",
      env: {
        "ATCODER_NO_BROWSER" => "1",
        "ATCODER_NO_CLIPBOARD" => "1",
        "FAKE_OJ_LOG" => log.to_s
      }
    )

    assert_predicate status, :success?, stderr
    records = log.readlines(chomp: true).map { |line| JSON.parse(line) }
    assert_equal %w[test], records.map { |record| record.fetch("action") }
    submission = @problem.join("submission.rb")
    assert_path_exists submission
    assert_equal records.first.fetch("sha256"), Digest::SHA256.file(submission).hexdigest
    assert_equal records.first.fetch("source"), submission.binread
    assert_includes records.first.fetch("source"), "SUBMIT_OFFSET = 4"
    assert_includes stdout, "Prepared browser submission"
    assert_includes stdout, "contest/a/submission.rb"
    assert_includes stdout, "Ruby 3.4.5 (language ID 6087)"
    assert_includes stdout, "https://atcoder.jp/contests/abc999/submit?taskScreenName=abc999_a"
    assert_empty temporary_bundles
  end

  def test_submit_copies_the_snapshot_and_opens_the_preselected_task
    log = @sandbox.join("oj.log")
    clipboard_log = @sandbox.join("clipboard.log")
    browser_log = @sandbox.join("browser.log")
    install_fake_oj
    clipboard = install_fake_command("clipboard", <<~'RUBY')
      File.binwrite(ENV.fetch("FAKE_CLIPBOARD_LOG"), $stdin.read)
    RUBY
    browser = install_fake_command("browser", <<~'RUBY')
      File.write(ENV.fetch("FAKE_BROWSER_LOG"), "#{ARGV.join("\n")}\n")
    RUBY
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts Integer($stdin.read) * 2
    RUBY
    write_problem_file("test/sample-1.in", "4\n")
    write_problem_file("test/sample-1.out", "8\n")
    write_problem_file(
      ".problem-url",
      "https://atcoder.jp/contests/abc999/tasks/abc999_a\n"
    )

    stdout, stderr, status = atcoder(
      "submit",
      "contest/a",
      env: {
        "ATCODER_BROWSER" => browser.to_s,
        "ATCODER_CLIPBOARD" => clipboard.to_s,
        "FAKE_BROWSER_LOG" => browser_log.to_s,
        "FAKE_CLIPBOARD_LOG" => clipboard_log.to_s,
        "FAKE_OJ_LOG" => log.to_s
      }
    )

    assert_predicate status, :success?, stderr
    submission = @problem.join("submission.rb")
    assert_equal submission.binread, clipboard_log.binread
    assert_equal(
      "https://atcoder.jp/contests/abc999/submit?taskScreenName=abc999_a\n",
      browser_log.read
    )
    assert_includes stdout, "Copied the bundled source to the clipboard."
    assert_includes stdout, "Opened the AtCoder submission page."
  end

  def test_bundle_replaces_its_own_generated_output
    write_library_value(1)
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts LibraryValue::VALUE
    RUBY
    _stdout, stderr, status = atcoder("bundle", "contest/a")
    assert_predicate status, :success?, stderr

    write_library_value(2)
    _updated_stdout, updated_stderr, updated_status = atcoder("bundle", "contest/a")

    assert_predicate updated_status, :success?, updated_stderr
    run_stdout, run_stderr, run_status = ruby(@problem.join("submission.rb"))
    assert_predicate run_status, :success?, run_stderr
    assert_equal "2\n", run_stdout
  end

  def test_bundle_refuses_to_overwrite_a_handwritten_submission
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts "solution"
    RUBY
    handwritten = "# handwritten\nputs :keep\n"
    @problem.join("submission.rb").binwrite(handwritten)

    _stdout, stderr, status = atcoder("bundle", "contest/a")

    refute_predicate status, :success?
    assert_includes stderr, "refusing to overwrite non-generated file"
    assert_equal handwritten, @problem.join("submission.rb").binread
  end

  def test_invalid_source_keeps_the_previous_bundle_and_cleans_up
    write_library_value(1)
    write_main(<<~RUBY)
      # frozen_string_literal: true

      puts LibraryValue::VALUE
    RUBY
    _stdout, stderr, status = atcoder("bundle", "contest/a")
    assert_predicate status, :success?, stderr
    previous = @problem.join("submission.rb").binread
    write_library("value.rb", <<~RUBY)
      # frozen_string_literal: true

      module Broken
    RUBY

    _failed_stdout, failed_stderr, failed_status = atcoder("bundle", "contest/a")

    refute_predicate failed_status, :success?
    assert_includes failed_stderr, "syntax error in library/value.rb"
    assert_equal previous, @problem.join("submission.rb").binread
    assert_empty temporary_bundles
  end

  def test_magic_comment_text_inside_a_string_is_not_a_declaration
    write_library("notes.rb", <<~RUBY)
      NOTES = "# frozen_string_literal: true"
    RUBY

    _stdout, stderr, status = atcoder("check-library")

    refute_predicate status, :success?
    assert_includes stderr, "must declare frozen_string_literal: true"
  end

  def test_require_relative_is_rejected_only_when_it_is_code
    write_library("notes.rb", <<~RUBY)
      # frozen_string_literal: true

      NOTES = ["require_relative", "# require_relative 'other'"]
    RUBY
    stdout, stderr, status = atcoder("check-library")
    assert_predicate status, :success?, stderr
    assert_includes stdout, "1 files valid"

    write_library("notes.rb", <<~RUBY)
      # frozen_string_literal: true

      require_relative "other"
    RUBY
    _failed_stdout, failed_stderr, failed_status = atcoder("check-library")

    refute_predicate failed_status, :success?
    assert_includes failed_stderr, "require_relative is not allowed"
  end

  def test_library_rejects_end_and_data_tokens
    {
      "__END__" => <<~RUBY,
        # frozen_string_literal: true

        VALUE = 1
        __END__
        payload
      RUBY
      "DATA" => <<~RUBY
        # frozen_string_literal: true

        VALUE = DATA
      RUBY
    }.each do |token, source|
      write_library("invalid.rb", source)

      _stdout, stderr, status = atcoder("check-library")

      refute_predicate status, :success?
      assert_includes stderr, "#{token} is not allowed"
    end
  end

  def test_library_rejects_non_utf8_magic_comment
    write_library("encoded.rb", <<~RUBY)
      # -*- coding: Shift_JIS; frozen_string_literal: true -*-

      VALUE = 1
    RUBY

    _stdout, stderr, status = atcoder("check-library")

    refute_predicate status, :success?
    assert_includes stderr, "only UTF-8 source files can be bundled"
  end

  def test_library_rejects_non_utf8_encoding_hidden_by_a_second_comment
    write_library("encoded.rb", <<~RUBY)
      # encoding: Shift_JIS
      # encoding: UTF-8
      # frozen_string_literal: true

      VALUE = 1
    RUBY

    _stdout, stderr, status = atcoder("check-library")

    refute_predicate status, :success?
    assert_includes stderr, "only UTF-8 source files can be bundled"
  end

  def test_library_rejects_invalid_utf8_bytes
    write_library(
      "encoded.rb",
      "# frozen_string_literal: true\nVALUE = \"\xFF\"\n".b
    )

    _stdout, stderr, status = atcoder("check-library")

    refute_predicate status, :success?
    assert_includes stderr, "source is not valid UTF-8"
  end

  def test_bundle_removes_utf8_bom_from_main_source
    write_main(
      "\xEF\xBB\xBF# frozen_string_literal: true\nputs \"bom-safe\"\n".b
    )

    _stdout, stderr, status = atcoder("bundle", "contest/a")

    assert_predicate status, :success?, stderr
    run_stdout, run_stderr, run_status = ruby(@problem.join("submission.rb"))
    assert_predicate run_status, :success?, run_stderr
    assert_equal "bom-safe\n", run_stdout
  end

  def test_library_rejects_raw_eof_control_bytes
    {
      "00" => "\x00",
      "04" => "\x04",
      "1A" => "\x1A"
    }.each do |hex, byte|
      write_library(
        "control.rb",
        "# frozen_string_literal: true\nVALUE = 1\n#{byte}IGNORED = 2\n".b
      )

      _stdout, stderr, status = atcoder("check-library")

      refute_predicate status, :success?
      assert_includes stderr, "0x#{hex}"
    end
  end

  def test_library_rejects_symbolic_links_of_any_extension
    outside = @sandbox.join("outside.txt")
    outside.write("outside")
    File.symlink(outside, @sandbox.join("library/notes.txt"))

    _stdout, stderr, status = atcoder("check-library")

    refute_predicate status, :success?
    assert_includes stderr, "symbolic links are not allowed"
  end

  def test_new_template_loads_the_library_when_run_directly
    FileUtils.cp(PROJECT_ROOT.join("library.rb"), @sandbox.join("library.rb"))
    write_library("direct.rb", <<~RUBY)
      # frozen_string_literal: true

      DIRECT_LIBRARY_VALUE = 12
    RUBY
    source = PROJECT_ROOT.join("template/main.rb").read.sub(
      "  # 解答をここに書く",
      "  puts DIRECT_LIBRARY_VALUE"
    )
    write_main(source)

    stdout, stderr, status = ruby(@problem.join("main.rb"))

    assert_predicate status, :success?, stderr
    assert_equal "12\n", stdout
  end

  private

  def write_main(source)
    @problem.join("main.rb").binwrite(source)
  end

  def write_library(relative_path, source)
    path = @sandbox.join("library", relative_path)
    path.parent.mkpath
    path.binwrite(source)
  end

  def write_library_value(value)
    write_library("value.rb", <<~RUBY)
      # frozen_string_literal: true

      module LibraryValue
        VALUE = #{value}
      end
    RUBY
  end

  def write_problem_file(relative_path, source)
    path = @problem.join(relative_path)
    path.parent.mkpath
    path.binwrite(source)
  end

  def install_fake_oj
    path = @sandbox.join(".venv/bin/oj")
    path.parent.mkpath
    path.write(<<~'RUBY')
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require "digest"
      require "json"
      require "open3"
      require "pathname"
      require "shellwords"

      action = ARGV.fetch(0)
      file = case action
      when "test"
        command_text = ARGV.fetch(ARGV.index("-c") + 1)
        Shellwords.split(command_text).last
      when "submit"
        ARGV.last
      else
        abort "unexpected fake oj action: #{action}"
      end

      path = Pathname(file).expand_path
      record = {
        action: action,
        argv: ARGV,
        file: path.basename.to_s,
        sha256: Digest::SHA256.file(path).hexdigest,
        source: path.binread
      }
      File.open(ENV.fetch("FAKE_OJ_LOG"), "a") { |log| log.puts(JSON.generate(record)) }

      exit 0 if action == "submit"

      command = Shellwords.split(ARGV.fetch(ARGV.index("-c") + 1))
      Dir["test/*.in"].sort.each do |input_file|
        expected_file = input_file.sub(/\.in\z/, ".out")
        stdout, stderr, status = Open3.capture3(
          *command,
          stdin_data: File.binread(input_file)
        )
        unless status.success? && stdout == File.binread(expected_file)
          warn stderr
          exit 1
        end
      end
    RUBY
    path.chmod(0o755)
  end

  def install_fake_command(name, source)
    path = @sandbox.join("fake-bin", name)
    path.parent.mkpath
    path.write(<<~RUBY)
      #!#{RbConfig.ruby}
      # frozen_string_literal: true

      #{source}
    RUBY
    path.chmod(0o755)
    path
  end

  def temporary_bundles
    @problem.glob(".atcoder-bundle-*.rb")
  end

  def atcoder(*arguments, env: {})
    Open3.capture3(
      env,
      RbConfig.ruby,
      @sandbox.join("bin/atcoder").to_s,
      *arguments,
      chdir: @sandbox.to_s
    )
  end

  def ruby(path, stdin_data: "")
    Open3.capture3(RbConfig.ruby, path.to_s, stdin_data:, chdir: path.parent.to_s)
  end
end
