# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class TemplateUpdateTest < Minitest::Test
  PROJECT_ROOT = Pathname(__dir__).parent
  UPDATE_TEMPLATE = PROJECT_ROOT.join("bin/update-template")
  VERSION_FILE = ".atcoder-template-version"
  GIT_ENVIRONMENT = {
    "GIT_CONFIG_GLOBAL" => "/dev/null",
    "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_TERMINAL_PROMPT" => "0",
    "LC_ALL" => "C"
  }.freeze

  def setup
    @temporary_directory = Pathname(Dir.mktmpdir("atcoder-template-update-"))
    @upstream = @temporary_directory.join("upstream")
    @solution = @temporary_directory.join("solution")
    initialize_repository(@upstream)
    initialize_repository(@solution)

    write(@upstream, VERSION_FILE, "1\n")
    write(@upstream, "framework.txt", "framework v1\n")
    write(@upstream, "shared.txt", "shared base\n")
    commit_all(@upstream, "Template version 1")

    write(@solution, VERSION_FILE, "1\n")
    write(@solution, "framework.txt", "framework v1\n")
    write(@solution, "shared.txt", "shared base\n")
    write(@solution, "solution.txt", "user solution\n")
    commit_all(@solution, "Independent solution repository")
  end

  def teardown
    FileUtils.remove_entry(@temporary_directory)
  end

  def test_adds_the_template_remote_and_reports_when_already_current
    head_before = git_stdout(@solution, "rev-parse", "HEAD")

    stdout, stderr, status = update_template

    assert_predicate status, :success?, stderr
    assert_includes stdout, "already up to date"
    assert_equal @upstream.to_s,
      git_stdout(@solution, "remote", "get-url", "template")
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
  end

  def test_cherry_picks_every_commit_after_the_recorded_version
    write(@upstream, "framework.txt", "framework v2\n")
    commit_all(@upstream, "Improve framework")
    write(@upstream, VERSION_FILE, "2\n")
    write(@upstream, "new-tool.txt", "new tool\n")
    commit_all(@upstream, "Template version 2")
    commit_count_before = git_stdout(@solution, "rev-list", "--count", "HEAD").to_i

    stdout, stderr, status = update_template

    assert_predicate status, :success?, stderr
    assert_includes stdout, "updated from template version 1 to 2"
    assert_equal "framework v2\n", @solution.join("framework.txt").read
    assert_equal "new tool\n", @solution.join("new-tool.txt").read
    assert_equal "2\n", @solution.join(VERSION_FILE).read
    assert_equal "user solution\n", @solution.join("solution.txt").read
    assert_equal commit_count_before + 2,
      git_stdout(@solution, "rev-list", "--count", "HEAD").to_i
  end

  def test_rejects_a_dirty_worktree_before_fetching
    write(@solution, "solution.txt", "uncommitted solution\n")
    head_before = git_stdout(@solution, "rev-parse", "HEAD")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, "working tree is not clean"
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
    refute_includes git_stdout(@solution, "remote"), "template"
  end

  def test_rejects_a_repository_without_a_template_version
    git!(@solution, "rm", VERSION_FILE)
    commit_all(@solution, "Remove template version")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, VERSION_FILE
    assert_includes stderr, "missing"
  end

  def test_rejects_upstream_changes_without_a_version_bump
    write(@upstream, "framework.txt", "unversioned change\n")
    commit_all(@upstream, "Forgot template version")
    head_before = git_stdout(@solution, "rev-parse", "HEAD")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, "version was not advanced"
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
  end

  def test_rejects_changes_after_the_latest_version_commit
    write(@upstream, VERSION_FILE, "2\n")
    commit_all(@upstream, "Template version 2")
    write(@upstream, "framework.txt", "unversioned trailing change\n")
    commit_all(@upstream, "Change after template version")
    head_before = git_stdout(@solution, "rev-parse", "HEAD")
    tree_before = git_stdout(@solution, "rev-parse", "HEAD^{tree}")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, "version was not advanced"
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
    assert_equal tree_before, git_stdout(@solution, "rev-parse", "HEAD^{tree}")
  end

  def test_rejects_an_unexpected_existing_template_remote
    git!(@solution, "remote", "add", "template", @upstream.to_s)
    head_before = git_stdout(@solution, "rev-parse", "HEAD")

    stdout, stderr, status = update_template(template_url: nil)

    refute_predicate status, :success?
    assert_includes stderr, "does not point to the official template"
    refute_includes stdout, "Fetching"
    assert_equal @upstream.to_s,
      git_stdout(@solution, "remote", "get-url", "template")
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
  end

  def test_rejects_a_reused_template_version
    write(@upstream, VERSION_FILE, "2\n")
    commit_all(@upstream, "Template version 2")
    write(@upstream, VERSION_FILE, "1\n")
    commit_all(@upstream, "Incorrectly reuse template version 1")
    head_before = git_stdout(@solution, "rev-parse", "HEAD")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, "was reused"
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
  end

  def test_rejects_an_invalid_remote_version_before_applying_any_commit
    write(@upstream, "framework.txt", "framework v2\n")
    commit_all(@upstream, "Improve framework")
    write(@upstream, VERSION_FILE, "invalid\n")
    commit_all(@upstream, "Invalid template version")
    head_before = git_stdout(@solution, "rev-parse", "HEAD")
    tree_before = git_stdout(@solution, "rev-parse", "HEAD^{tree}")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, "invalid template version"
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
    assert_equal tree_before, git_stdout(@solution, "rev-parse", "HEAD^{tree}")
    assert_equal "framework v1\n", @solution.join("framework.txt").read
  end

  def test_leaves_a_conflicted_cherry_pick_with_recovery_instructions
    write(@upstream, "shared.txt", "shared from template\n")
    write(@upstream, VERSION_FILE, "2\n")
    commit_all(@upstream, "Template version 2")
    write(@solution, "shared.txt", "shared from solution\n")
    commit_all(@solution, "Customize shared file")
    head_before = git_stdout(@solution, "rev-parse", "HEAD")
    tree_before = git_stdout(@solution, "rev-parse", "HEAD^{tree}")

    _stdout, stderr, status = update_template

    refute_predicate status, :success?
    assert_includes stderr, "git cherry-pick --continue"
    assert_includes stderr, "git cherry-pick --abort"
    assert_predicate @solution.join(".git/CHERRY_PICK_HEAD"), :file?
    assert_includes git_stdout(@solution, "status", "--short"), "UU shared.txt"

    git!(@solution, "cherry-pick", "--abort")

    refute_predicate @solution.join(".git/CHERRY_PICK_HEAD"), :exist?
    assert_equal head_before, git_stdout(@solution, "rev-parse", "HEAD")
    assert_equal tree_before, git_stdout(@solution, "rev-parse", "HEAD^{tree}")
    assert_equal "", git_stdout(@solution, "status", "--short")
    assert_equal "shared from solution\n", @solution.join("shared.txt").read
  ensure
    git(@solution, "cherry-pick", "--abort") if
      @solution&.join(".git/CHERRY_PICK_HEAD")&.exist?
  end

  private

  def initialize_repository(path)
    path.mkpath
    git!(path, "init", "-b", "main")
    git!(path, "config", "user.name", "AtCoder Workspace Test")
    git!(path, "config", "user.email", "atcoder-workspace@example.invalid")
  end

  def write(repository, relative_path, content)
    path = repository.join(relative_path)
    path.parent.mkpath
    path.write(content)
  end

  def commit_all(repository, message)
    git!(repository, "add", "--all")
    git!(repository, "commit", "-m", message)
  end

  def update_template(template_url: @upstream.to_s)
    environment = GIT_ENVIRONMENT.dup
    environment["ATCODER_TEMPLATE_URL"] = template_url if template_url

    Open3.capture3(
      environment,
      UPDATE_TEMPLATE.to_s,
      chdir: @solution.to_s
    )
  end

  def git(repository, *arguments)
    Open3.capture3(
      GIT_ENVIRONMENT,
      "git",
      "-C",
      repository.to_s,
      *arguments
    )
  end

  def git!(repository, *arguments)
    stdout, stderr, status = git(repository, *arguments)
    return stdout if status.success?

    flunk "git #{arguments.join(' ')} failed:\n#{stdout}#{stderr}"
  end

  def git_stdout(repository, *arguments)
    stdout, stderr, status = git(repository, *arguments)
    assert_predicate status, :success?, stderr
    stdout.strip
  end
end
