from onlinejudge.service.atcoder import AtCoderProblem, AtCoderProblemData


def parse_memory_limit(time_limit_text: str, memory_limit_text: str) -> int:
    problem = AtCoderProblem.from_url(
        "https://atcoder.jp/contests/abc468/tasks/abc468_a"
    )
    if problem is None:
        raise AssertionError("failed to construct the AtCoder problem")

    html = f"""
        <span class="h2">A - Parser compatibility test</span>
        <p>{time_limit_text} / {memory_limit_text}</p>
    """.encode()
    data = AtCoderProblemData._from_html(html, problem=problem)
    return data.memory_limit_byte


def main() -> None:
    cases = [
        ("Time Limit: 2 sec", "Memory Limit: 1024 MiB", 1024 * 1024 * 1024),
        ("実行時間制限: 2000 msec", "メモリ制限: 512 KiB", 512 * 1024),
        ("Time Limit: 2 sec", "Memory Limit: 256 MB", 256 * 1000 * 1000),
        ("実行時間制限: 2000 msec", "メモリ制限: 64 KB", 64 * 1000),
    ]
    for time_limit_text, memory_limit_text, expected_bytes in cases:
        actual_bytes = parse_memory_limit(time_limit_text, memory_limit_text)
        if actual_bytes != expected_bytes:
            raise AssertionError(
                f"{memory_limit_text}: expected {expected_bytes}, got {actual_bytes}"
            )


if __name__ == "__main__":
    main()
