# frozen_string_literal: true

require "json"
require "fileutils"
require "minitest/autorun"
require "pathname"
require "stringio"
require "tmpdir"

load File.expand_path("../bin/contest-guard", __dir__)

class ContestGuardTest < Minitest::Test
  PROJECT_ROOT = Pathname(__dir__).parent
  FIXTURE = PROJECT_ROOT.join("test/fixtures/contest_guard/abc469.html").read
  START_AT = Time.iso8601("2026-08-01T21:00:00+09:00")
  END_AT = Time.iso8601("2026-08-01T22:40:00+09:00")
  CLEAR_AFTER = END_AT + AtCoderContestGuard::END_SAFETY_MARGIN

  FakeResponse = Struct.new(:body, :server_time, keyword_init: true)

  class FakeFetcher
    attr_reader :uris

    def initialize(body:, server_time:)
      @body = body
      @server_time = server_time
      @uris = []
    end

    def call(uri)
      @uris << uri
      FakeResponse.new(body: @body, server_time: @server_time)
    end
  end

  def setup
    @root = Pathname(Dir.mktmpdir("atcoder-contest-guard-"))
  end

  def teardown
    FileUtils.remove_entry(@root) if @root&.directory?
  end

  def test_manual_lock_is_repository_wide_and_only_unlock_removes_it
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)
    guard = build_guard(fetcher:)

    lock = guard.lock("abc469")
    marker = @root.join(".atcoder-contest-lock")
    marker_bytes = marker.binread
    metadata = JSON.parse(marker_bytes)

    assert lock.success?
    assert_equal 1, metadata.fetch("version")
    assert_equal "abc469", metadata.fetch("contest_id")
    assert_equal "2026-07-31T00:00:00Z", metadata.fetch("locked_at")
    assert_equal 0o600, marker.stat.mode & 0o700
    assert_equal 0, marker.stat.mode & 0o077

    decision = guard.check("arc200")

    refute decision.allowed?
    assert_equal :locked, decision.state
    assert_empty fetcher.uris
    assert_equal marker_bytes, marker.binread

    assert guard.unlock.success?
    refute marker.exist?

    ended = guard.check("abc469")

    assert ended.allowed?
    assert_equal :ended, ended.state
    assert_equal(
      ["https://atcoder.jp/contests/abc469?lang=en"],
      fetcher.uris.map(&:to_s)
    )
  end

  def test_existing_lock_is_idempotent_and_is_not_overwritten
    guard = build_guard
    first = guard.lock("abc469")
    marker = @root.join(".atcoder-contest-lock")
    bytes = marker.binread

    second = guard.lock("arc200")

    assert first.success?
    assert second.success?
    refute second.changed?
    assert_equal bytes, marker.binread
  end

  def test_corrupt_and_non_regular_markers_fail_closed
    marker = @root.join(".atcoder-contest-lock")
    marker.write("{not json")
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: END_AT)
    guard = build_guard(fetcher:)

    decision = guard.check("abc469")

    refute decision.allowed?
    assert_equal :locked, decision.state
    assert_empty fetcher.uris
    assert guard.unlock.success?

    target = @root.join("outside")
    target.write("keep")
    marker.make_symlink(target)

    symlink_decision = guard.check("abc469")
    unlock = guard.unlock

    refute symlink_decision.allowed?
    assert_equal :locked, symlink_decision.state
    refute unlock.success?
    assert marker.symlink?
    assert_equal "keep", target.read

    marker.unlink
    marker.mkdir
    directory_decision = guard.check("abc469")

    refute directory_decision.allowed?
    assert_equal :locked, directory_decision.state
    refute guard.unlock.success?
  end

  def test_official_schedule_uses_pre_start_and_post_end_safety_margins
    upcoming = build_guard(
      fetcher: FakeFetcher.new(
        body: FIXTURE,
        server_time: START_AT - AtCoderContestGuard::START_SAFETY_MARGIN - 1
      )
    ).check("abc469")
    starting_soon = build_guard(
      fetcher: FakeFetcher.new(
        body: FIXTURE,
        server_time: START_AT - AtCoderContestGuard::START_SAFETY_MARGIN
      )
    ).check("abc469")
    starting = build_guard(
      fetcher: FakeFetcher.new(
        body: FIXTURE,
        server_time: START_AT
      )
    ).check("abc469")
    ending = build_guard(
      fetcher: FakeFetcher.new(
        body: FIXTURE,
        server_time: END_AT
      )
    ).check("abc469")
    cooling_down = build_guard(
      fetcher: FakeFetcher.new(
        body: FIXTURE,
        server_time: CLEAR_AFTER - 1
      )
    ).check("abc469")
    ended = build_guard(
      fetcher: FakeFetcher.new(
        body: FIXTURE,
        server_time: CLEAR_AFTER
      )
    ).check("abc469")

    assert upcoming.allowed?
    assert_equal :upcoming, upcoming.state
    refute starting_soon.allowed?
    assert_equal :starting_soon, starting_soon.state
    refute starting.allowed?
    assert_equal :ongoing, starting.state
    refute ending.allowed?
    assert_equal :cooldown, ending.state
    refute cooling_down.allowed?
    assert_equal :cooldown, cooling_down.state
    assert ended.allowed?
    assert_equal :ended, ended.state
    refute @root.join(".atcoder-contest-lock").exist?
  end

  def test_lock_created_during_fetch_wins_before_clear_is_returned
    marker = @root.join(".atcoder-contest-lock")
    fetcher = Object.new
    fetcher.define_singleton_method(:call) do |_uri|
      marker.write("{}")
      FakeResponse.new(body: FIXTURE, server_time: CLEAR_AFTER)
    end

    decision = build_guard(fetcher:).check_contest("abc469")

    refute decision.allowed?
    assert_equal :locked, decision.state
  end

  def test_check_resolves_contest_from_workspace_metadata
    contest = @root.join("abc469")
    problem = contest.join("a")
    problem.mkpath
    contest.join(".contest.json").write(<<~JSON)
      {
        "id": "abc469",
        "url": "https://atcoder.jp/contests/abc469",
        "tasks": []
      }
    JSON
    problem.join(".problem-url").write(
      "https://atcoder.jp/contests/abc469/tasks/abc469_a\n"
    )
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)

    decision = build_guard(fetcher:).check(problem.join("main.rb").to_s)

    assert decision.allowed?
    assert_equal :ended, decision.state
    assert_equal 1, fetcher.uris.length
  end

  def test_conflicting_or_invalid_metadata_fails_closed_without_fetching
    contest = @root.join("abc469")
    problem = contest.join("a")
    problem.mkpath
    contest.join(".contest.json").write(<<~JSON)
      {
        "id": "abc469",
        "url": "https://atcoder.jp/contests/abc469",
        "tasks": []
      }
    JSON
    problem.join(".problem-url").write(
      "https://atcoder.jp/contests/abc468/tasks/abc468_a\n"
    )
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)

    conflict = build_guard(fetcher:).check(problem.to_s)
    contest.join(".contest.json").write("{broken")
    broken = build_guard(fetcher:).check(problem.to_s)

    [conflict, broken].each do |decision|
      refute decision.allowed?
      assert_equal :indeterminate, decision.state
    end
    assert_empty fetcher.uris
  end

  def test_existing_id_shaped_path_does_not_bypass_conflicting_metadata
    contest = @root.join("abc469")
    contest.mkpath
    contest.join(".contest.json").write(<<~JSON)
      {
        "id": "abc468",
        "url": "https://atcoder.jp/contests/abc468",
        "tasks": []
      }
    JSON
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)

    decision = build_guard(fetcher:).check("abc469")

    refute decision.allowed?
    assert_equal :indeterminate, decision.state
    assert_empty fetcher.uris
  end

  def test_explicit_contest_must_match_supplied_target_path
    contest = @root.join("abc469")
    contest.mkpath
    contest.join(".contest.json").write(<<~JSON)
      {
        "id": "abc469",
        "url": "https://atcoder.jp/contests/abc469",
        "tasks": []
      }
    JSON
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)

    decision = build_guard(fetcher:).check_contest("abc468", contest.to_s)

    refute decision.allowed?
    assert_equal :indeterminate, decision.state
    assert_empty fetcher.uris
  end

  def test_problem_url_is_used_when_contest_metadata_is_absent
    problem = @root.join("abc469/a")
    problem.mkpath
    problem.join(".problem-url").write(
      "https://atcoder.jp/contests/abc469/tasks/abc469_a\n"
    )
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)

    decision = build_guard(fetcher:).check(problem.to_s)

    assert decision.allowed?
    assert_equal :ended, decision.state
    assert_equal 1, fetcher.uris.length
  end

  def test_unknown_family_and_path_outside_workspace_fail_closed
    fetcher = FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)
    guard = build_guard(fetcher:)

    ahc = guard.check("ahc050")
    outside = guard.check(@root.parent.join("abc469/a").to_s)

    [ahc, outside].each do |decision|
      refute decision.allowed?
      assert_equal :indeterminate, decision.state
    end
    assert_empty fetcher.uris
  end

  def test_fetch_and_schedule_parse_failures_fail_closed
    failures = [
      ["", CLEAR_AFTER],
      [FIXTURE.sub('var endTime = moment("2026-08-01T22:40:00+09:00");', ""), CLEAR_AFTER],
      [FIXTURE.sub("abc469", "abc468"), CLEAR_AFTER],
      [FIXTURE.sub("2026-08-01T22:40:00+09:00", "not-a-time"), CLEAR_AFTER],
      [FIXTURE.sub("2026-08-01T22:40:00+09:00", "2026-08-01T22:40:00"), CLEAR_AFTER],
      [FIXTURE.sub("2026-08-01T22:40:00+09:00", "2026-02-30T22:40:00+09:00"), CLEAR_AFTER],
      [FIXTURE.sub("2026-08-01T22:40:00+09:00", "2026-08-01T20:40:00+09:00"), CLEAR_AFTER],
      [FIXTURE, nil]
    ]

    failures.each do |body, server_time|
      decision = build_guard(
        fetcher: FakeFetcher.new(body:, server_time:)
      ).check("abc469")

      refute decision.allowed?
      assert_equal :indeterminate, decision.state
    end

    duplicate = FIXTURE.sub(
      'var endTime = moment("2026-08-01T22:40:00+09:00");',
      <<~JS.chomp
        var endTime = moment("2026-08-01T22:40:00+09:00");
        var endTime = moment("2026-08-01T22:41:00+09:00");
      JS
    )
    decision = build_guard(
      fetcher: FakeFetcher.new(body: duplicate, server_time: CLEAR_AFTER)
    ).check("abc469")

    refute decision.allowed?
    assert_equal :indeterminate, decision.state
  end

  def test_fetch_exception_fails_closed_without_creating_a_lock
    fetcher = Object.new
    def fetcher.call(_uri)
      raise Timeout::Error, "timed out"
    end

    decision = build_guard(fetcher:).check("abc469")

    refute decision.allowed?
    assert_equal :indeterminate, decision.state
    refute @root.join(".atcoder-contest-lock").exist?
  end

  def test_cli_distinguishes_clear_blocked_indeterminate_and_usage
    ongoing_guard = build_guard(
      fetcher: FakeFetcher.new(body: FIXTURE, server_time: START_AT)
    )
    clear_guard = build_guard(
      fetcher: FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER)
    )
    stdout = StringIO.new
    stderr = StringIO.new

    clear_status = AtCoderContestGuardCLI.run(
      %w[check --contest abc469],
      guard: clear_guard,
      stdout:,
      stderr:
    )
    ongoing_status = AtCoderContestGuardCLI.run(
      %w[check --contest abc469],
      guard: ongoing_guard,
      stdout:,
      stderr:
    )
    indeterminate_status = AtCoderContestGuardCLI.run(
      %w[check --contest ahc050],
      guard: ongoing_guard,
      stdout:,
      stderr:
    )
    usage_status = AtCoderContestGuardCLI.run(
      %w[check],
      guard: ongoing_guard,
      stdout:,
      stderr:
    )

    assert_equal 0, clear_status
    assert_includes stdout.string, "CLEAR"
    assert_equal 1, ongoing_status
    assert_equal 1, indeterminate_status
    assert_includes stderr.string, "BLOCKED"
    assert_equal 2, usage_status
  end

  def test_http_fetcher_uses_atcoder_server_time_and_no_cache_requests
    requests = []
    requester = lambda do |uri, headers|
      requests << [uri, headers]
      body = if uri.path == "/servertime"
        "2026-08-01 20:54:59+0900"
      else
        FIXTURE
      end
      FakeHttpResponse.new(code: "200", body:, headers: {})
    end
    fetcher = AtCoderContestGuard::HttpFetcher.new(
      requester:,
      nonce: -> { "123" }
    )

    response = fetcher.call(URI("https://atcoder.jp/contests/abc469?lang=en"))

    assert_equal FIXTURE, response.body
    assert_equal Time.iso8601("2026-08-01T20:54:59+09:00"), response.server_time
    assert_equal(
      [
        "https://atcoder.jp/contests/abc469?lang=en",
        "https://atcoder.jp/servertime?ts=123"
      ],
      requests.map { |uri, _headers| uri.to_s }
    )
    requests.each do |_uri, headers|
      assert_equal "no-cache, no-store", headers.fetch("Cache-Control")
      assert_equal "no-cache", headers.fetch("Pragma")
    end
  end

  def test_http_fetcher_rejects_unsafe_redirects_and_bad_server_time
    unsafe_redirect = AtCoderContestGuard::HttpFetcher.new(
      requester: lambda do |_uri, _headers|
        FakeHttpResponse.new(
          code: "302",
          body: "",
          headers: { "location" => "https://example.com/" }
        )
      end
    )
    bad_time = AtCoderContestGuard::HttpFetcher.new(
      requester: lambda do |uri, _headers|
        body = uri.path == "/servertime" ? "not-a-time" : FIXTURE
        FakeHttpResponse.new(code: "200", body:, headers: {})
      end
    )
    invalid_calendar_time = AtCoderContestGuard::HttpFetcher.new(
      requester: lambda do |uri, _headers|
        body = if uri.path == "/servertime"
          "2026-02-30 20:54:59+0900"
        else
          FIXTURE
        end
        FakeHttpResponse.new(code: "200", body:, headers: {})
      end
    )

    assert_raises(AtCoderContestGuard::GuardError) do
      unsafe_redirect.call(URI("https://atcoder.jp/contests/abc469"))
    end
    assert_raises(AtCoderContestGuard::GuardError) do
      bad_time.call(URI("https://atcoder.jp/contests/abc469"))
    end
    assert_raises(AtCoderContestGuard::GuardError) do
      invalid_calendar_time.call(
        URI("https://atcoder.jp/contests/abc469")
      )
    end
  end

  private

  FakeHttpResponse = Struct.new(:code, :body, :headers, keyword_init: true) do
    def [](name)
      headers[name.downcase]
    end
  end

  def build_guard(fetcher: FakeFetcher.new(body: FIXTURE, server_time: CLEAR_AFTER))
    AtCoderContestGuard.new(
      root: @root,
      fetcher:,
      clock: -> { Time.iso8601("2026-07-31T09:00:00+09:00") }
    )
  end
end
