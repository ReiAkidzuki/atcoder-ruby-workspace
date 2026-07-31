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

  def test_apple_silicon_selects_libtorch_2_8_archive
    stdout, stderr, status = run_libtorch_selector("Darwin", "arm64")

    assert_predicate status, :success?, stderr
    assert_equal(
      "https://download.pytorch.org/libtorch/cpu/libtorch-macos-arm64-2.8.0.zip\n",
      stdout
    )
  end

  def test_atcoder_linux_selects_libtorch_2_8_cpu_archive
    stdout, stderr, status = run_libtorch_selector("Linux", "x86_64")

    assert_predicate status, :success?, stderr
    assert_equal(
      "https://download.pytorch.org/libtorch/cpu/" \
        "libtorch-shared-with-deps-2.8.0%2Bcpu.zip\n",
      stdout
    )
  end

  def test_apple_silicon_libtorch_archive_has_a_pinned_sha256
    stdout, stderr, status = run_libtorch_checksum_selector("Darwin", "arm64")

    assert_predicate status, :success?, stderr
    assert_equal(
      "be0642231d2008c7b90071fc0898d82a0c002d47f38350ebf3ed779fc01972d7\n",
      stdout
    )
  end

  def test_atcoder_linux_libtorch_archive_has_a_pinned_sha256
    stdout, stderr, status = run_libtorch_checksum_selector("Linux", "x86_64")

    assert_predicate status, :success?, stderr
    assert_equal(
      "8dea5bcfed4b53ca0f6852517bea4b4d1f3ff1cc0c21da662e834d34af1ec824\n",
      stdout
    )
  end

  def test_unsupported_libtorch_platform_is_rejected
    _stdout, stderr, status = run_libtorch_selector("Darwin", "x86_64")

    refute_predicate status, :success?
    assert_includes stderr, "unsupported LibTorch platform"
  end

  def test_torch_extension_is_rebuilt_after_the_workspace_moves
    Dir.mktmpdir("atcoder-torch-build-info-") do |temporary_directory|
      gem_home = Pathname(temporary_directory)
      build_info = gem_home.join("build_info/torch-rb-0.21.0.info")
      build_info.parent.mkpath
      build_info.write("--with-torch-dir=/old/workspace/.cache/libtorch\n")

      _stdout, stderr, status = run_torch_rebuild_check(
        gem_home,
        "/new/workspace/.cache/libtorch"
      )

      assert_predicate status, :success?, stderr
    end
  end

  def test_torch_extension_is_kept_when_libtorch_path_matches
    Dir.mktmpdir("atcoder-torch-build-info-") do |temporary_directory|
      gem_home = Pathname(temporary_directory)
      build_info = gem_home.join("build_info/torch-rb-0.21.0.info")
      build_info.parent.mkpath
      libtorch = "/current/workspace/.cache/libtorch"
      build_info.write("--with-torch-dir=#{libtorch}\n")

      _stdout, _stderr, status = run_torch_rebuild_check(gem_home, libtorch)

      refute_predicate status, :success?
    end
  end

  def test_missing_torch_extension_does_not_request_a_rebuild
    Dir.mktmpdir("atcoder-torch-build-info-") do |temporary_directory|
      _stdout, _stderr, status = run_torch_rebuild_check(
        Pathname(temporary_directory),
        "/current/workspace/.cache/libtorch"
      )

      refute_predicate status, :success?
    end
  end

  def test_workspace_marker_detects_a_move_without_torch_build_info
    Dir.mktmpdir("atcoder-workspace-marker-") do |temporary_directory|
      directory = Pathname(temporary_directory)
      marker = directory.join("workspace-path")
      marker.write("/old/workspace\n")

      _stdout, stderr, status = run_workspace_move_check(
        marker,
        "/new/workspace",
        directory.join("gems"),
        "/new/workspace/.cache/libtorch"
      )

      assert_predicate status, :success?, stderr
    end
  end

  def test_current_workspace_marker_does_not_request_a_rebuild
    Dir.mktmpdir("atcoder-workspace-marker-") do |temporary_directory|
      directory = Pathname(temporary_directory)
      marker = directory.join("workspace-path")
      marker.write("/current/workspace\n")

      _stdout, _stderr, status = run_workspace_move_check(
        marker,
        "/current/workspace",
        directory.join("gems"),
        "/current/workspace/.cache/libtorch"
      )

      refute_predicate status, :success?
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

  def run_libtorch_selector(os_name, architecture)
    script = <<~SH
      source #{Shellwords.escape(PLATFORM_HELPER.to_s)}
      ATCODER_OS=#{Shellwords.escape(os_name)} \
        ATCODER_ARCH=#{Shellwords.escape(architecture)} \
        atcoder_libtorch_url
    SH
    Open3.capture3("/bin/bash", "-c", script)
  end

  def run_libtorch_checksum_selector(os_name, architecture)
    script = <<~SH
      source #{Shellwords.escape(PLATFORM_HELPER.to_s)}
      ATCODER_OS=#{Shellwords.escape(os_name)} \
        ATCODER_ARCH=#{Shellwords.escape(architecture)} \
        atcoder_libtorch_sha256
    SH
    Open3.capture3("/bin/bash", "-c", script)
  end

  def run_torch_rebuild_check(gem_home, libtorch)
    script = <<~SH
      source #{Shellwords.escape(PLATFORM_HELPER.to_s)}
      atcoder_torch_needs_rebuild \
        #{Shellwords.escape(gem_home.to_s)} \
        #{Shellwords.escape(libtorch)}
    SH
    Open3.capture3("/bin/bash", "-c", script)
  end

  def run_workspace_move_check(marker, project_root, gem_home, libtorch)
    script = <<~SH
      source #{Shellwords.escape(PLATFORM_HELPER.to_s)}
      atcoder_workspace_moved \
        #{Shellwords.escape(marker.to_s)} \
        #{Shellwords.escape(project_root)} \
        #{Shellwords.escape(gem_home.to_s)} \
        #{Shellwords.escape(libtorch)}
    SH
    Open3.capture3("/bin/bash", "-c", script)
  end
end
