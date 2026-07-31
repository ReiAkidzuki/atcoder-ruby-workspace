# AtCoder Ruby workspace

**English** | [日本語](README.ja.md)

A workspace targeting AtCoder's Ruby 3.4.5 (CRuby) environment.
It keeps solutions and custom libraries separate, then bundles them into a single Ruby file for local runs and submissions.

## Start from GitHub

To create a new solution repository, select **Use this template** and then **Create a new repository** on GitHub.
A repository created from this template has an independent history, so you do not need to fork the original repository.

To share the same solutions and custom libraries across multiple machines, create one repository from the template and clone that same repository on each machine.
Cookies are not stored in the repository, so run `make login` on every machine used for submissions.

## Installation

This workspace supports Apple Silicon Macs and Debian/Ubuntu-based x86_64 Linux.
On Windows, use Ubuntu under WSL.

Install [rbenv](https://github.com/rbenv/rbenv), [ruby-build](https://github.com/rbenv/ruby-build), and [uv](https://docs.astral.sh/uv/getting-started/installation/) first.
On macOS, you can install them with Homebrew:

```sh
brew install rbenv ruby-build uv
rbenv init
```

After running `rbenv init`, follow its instructions and restart your terminal.

On Debian/Ubuntu-based Linux, install the [build environment recommended by ruby-build](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment) and the `time` package that provides GNU time.
Then install rbenv and uv according to their official instructions, and run `rbenv init`.

After cloning the repository, run:

```sh
make setup
make doctor
make self-test
```

`make setup` installs Ruby 3.4.5, the gems and native libraries in the regular profile, online-judge-tools (`oj`), and the AtCoder login helper (`aclogin`).
The regular `make setup` installs only ten lightweight competitive-programming gems and skips the large numerical, optimization, and machine-learning gems.
Its native dependencies on macOS follow `Brewfile.core`, while Ruby dependencies follow `Gemfile.lock`.

Install the full profile when you need every nonstandard gem provided by AtCoder:

```sh
make setup-full
```

`make setup-full` follows the complete `Brewfile` and adds OpenBLAS, OR-Tools, Polars, Torch, and the other optional gems.
Its first run takes time because it downloads LibTorch and builds native extensions.
Native compilation is generally configured to use two parallel jobs.
Override it with a command such as `ATCODER_BUILD_JOBS=4 make setup-full` if appropriate, although a few gems such as `numo-openblas` select the available CPU count themselves.
`make doctor` checks Ruby, Bundler, the pinned gems, native libraries, and the AtCoder commands for the selected profile.
Under the core profile it reports optional gem checks as `skip`.
When every item it reports is `ok`, the local environment is ready.
`make self-test` runs the workspace's regression tests in a temporary directory without making network requests.

## AtCoder Ruby 3.4.5 environment

This repository follows AtCoder's [available languages and libraries](https://img.atcoder.jp/file/language-update/2025-10/language-list.html) and its [official Ruby environment configuration](https://img.atcoder.jp/file/language-update/2025-10/087-3-3_ruby-3-3-6.toml).
The official configuration URL retains an older filename, but the configuration itself specifies Ruby 3.4.5.
It uses RubyGems 3.6.9 and Bundler 2.6.9 as shipped with Ruby 3.4.5, and `Gemfile` pins the following 20 nonstandard gems listed directly by AtCoder:

| Gem | Version | Gem | Version |
| --- | --- | --- | --- |
| `ac-library-rb` | 1.2.0 | `bit_utils` | 0.1.2 |
| `bitarray` | 1.3.1 | `fast_trie` | 0.5.1 |
| `faster_prime` | 1.0.2 | `ffi-geos` | 2.5.0 |
| `immutable-ruby` | 0.2.0 | `lightgbm` | 0.4.3 |
| `numo-linalg` | 0.1.7 | `numo-narray` | 0.9.2.1 |
| `numo-openblas` | 0.5.1 | `or-tools` | 0.16.0 |
| `polars-df` | 0.21.1 | `rbtree` | 0.4.6 |
| `rgl` | 0.6.6 | `rumale` | 1.0.0 |
| `sorted_containers` | 1.1.0 | `sorted_set` | 1.0.3 |
| `torch-rb` | 0.21.0 | `z3` | 0.0.20230311 |

There are two installation profiles:

- Regular `make setup`: `ac-library-rb`, `bit_utils`, `bitarray`, `fast_trie`, `faster_prime`, `immutable-ruby`, `rbtree`, `rgl`, `sorted_containers`, and `sorted_set`
- `make setup-full`: all of the above plus `ffi-geos`, `lightgbm`, `numo-linalg`, `numo-narray`, `numo-openblas`, `or-tools`, `polars-df`, `rumale`, `torch-rb`, and `z3`

Run `make setup-full` before using a gem from the second list in a solution.
Running `make setup` after a full installation does not delete downloaded optional gems, avoiding another lengthy build if you switch back.
It only changes the selected validation profile to core.

To isolate this workspace from gems installed by other projects, `make setup` installs gems under `.bundle/gems`.
The [gems bundled with Ruby 3.4.5](https://github.com/ruby/ruby/blob/v3_4_5/gems/bundled_gems) are pinned to their distribution versions as well, preventing Bundler from replacing them with newer releases.
`Gemfile.lock` records both macOS arm64 and Linux x86_64 platforms and includes checksums for reproducible dependency resolution.

`Brewfile.core` defines GNU time, pkg-config, and Rust for the regular macOS profile.
The full `Brewfile` adds CMake, GCC, GEOS, LLVM OpenMP, OpenBLAS, and Z3.
On Debian/Ubuntu-based Linux, setup likewise installs only the apt packages required by the selected profile.
`make setup-full` downloads the official LibTorch 2.8.0 archive for the current OS and CPU into `.cache/libtorch/`, as required by `torch-rb` 0.21.0, and verifies its pinned SHA-256 before extraction.
After moving a repository configured with the full profile, run `make setup-full` again so the Torch and OpenBLAS extensions are rebuilt for the new absolute path.

Bundler is used only to pin the local dependency environment.
The `test`, `run`, and `random` commands use that pinned environment, but the generated `submission.rb` does not load `Gemfile` or Bundler.
AtCoder executes submitted code with the regular `ruby --jit Main.rb` command from its official configuration.

## Browser login and the optional `oj` cookie

AtCoder has [introduced CAPTCHA for source-code submissions](https://atcoder.jp/posts/1457?lang=en), and the current submission form uses [Cloudflare Turnstile](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/).
The verification token is generated in a real browser, so this workspace hands the final submission step to the browser instead of trying to bypass it with a raw HTTP request.
Log in to AtCoder in your regular browser before running `bin/atcoder submit`.
The normal browser-assisted submission flow does not require `make login` or copying a cookie.

If an authenticated, read-only `oj` operation needs its own session, log in to AtCoder in a browser, copy only the value of the `REVEL_SESSION` cookie from the browser's developer tools, and then run:

```sh
make login
```

Paste the cookie value into the prompt.
The cookie is stored in `oj`'s user data directory and is never stored in this repository.
Do not paste the cookie value into source code, commits, or chats.
Public task listings, problem scaffolding, sample downloads, and local tests usually work without it.
If sample download is rejected because authentication is required, run `make login`.
Even with a valid `oj` cookie, `oj submit` can be rejected because it cannot produce the browser's Turnstile verification token.

## Usage

List all tasks in a contest:

```sh
bin/atcoder tasks abc468
```

Create `main.rb` files and download samples for every task in a contest:

```sh
bin/atcoder contest abc468
```

The generated layout looks like this:

```text
abc468/
├── .contest.json
├── a/
│   ├── .problem-url
│   ├── main.rb
│   └── test/
│       ├── .samples-complete
│       ├── sample-1.in
│       └── sample-1.out
├── b/
└── ...
```

`.samples-complete` is an automatically managed marker that records successful sample retrieval.
You do not need to edit or delete it.

To create only one task, provide either its problem URL or a contest ID and task label:

```sh
bin/atcoder new abc468 a
# Use a URL for older contests or tasks with nonstandard problem IDs.
bin/atcoder new https://atcoder.jp/contests/abc001/tasks/abc001_1
```

After writing a solution, use `test` for official samples and manual cases, or `run` for manual execution.
Both commands use the same `ruby --jit` command as AtCoder:

```sh
bin/atcoder test abc468/a
bin/atcoder run abc468/a
bin/atcoder run abc468/a input.txt
```

## Custom libraries

Place custom libraries under `library/` as `.rb` files.
Subdirectories are supported, and all files matching `library/**/*.rb` are bundled in lexicographic order by relative path.
To temporarily exclude a work-in-progress file, change its extension to something such as `.rb.disabled`.
Files and directories whose names start with a dot are excluded.

```text
library/
├── 00_core/
│   └── union_find.rb
├── 10_data_structure/
│   └── fenwick_tree.rb
└── 20_graph/
    └── dijkstra.rb
```

Ordering uses the complete path relative to `library/`, not only the filename.
When dependencies span directories, add numeric prefixes to directory names as shown above.
Dependencies are not analyzed automatically.
Define libraries under uniquely named `module` or `class` namespaces to avoid top-level name collisions.
Symbolic links are not allowed anywhere under `library/`, regardless of their extension.

The `test`, `run`, `random`, and `submit` commands bundle the latest libraries with the target `main.rb` into a temporary file every time they run.
They do not modify the existing `main.rb`.
During random testing, libraries are bundled only with the solution; the generator and oracle remain independent.
For submission, the exact file that passed all local tests is saved as `submission.rb` and handed to the browser.
A newly generated `main.rb` also loads libraries from the project root when run directly.
A `main.rb` not based on the current template may not load libraries when invoked directly with `ruby`; `bin/atcoder run` always creates the bundle first.

Libraries may load standard-library files, for example with `require "set"`.
`require_relative` is rejected during bundling in both `main.rb` and library files because its meaning changes after files are combined.
`__END__` and `DATA` are also unavailable in library files.
Save `main.rb` and every library as UTF-8.
AtCoder runs Ruby as [`ruby --jit Main.rb`](https://img.atcoder.jp/file/language-update/2025-10/language-list.html), without forcing frozen string literals, so the template follows Ruby's default and does not add `# frozen_string_literal: true`.
You do not need to write that directive in solution or library files.
If existing files explicitly opt in with `true`, bundling promotes it to one solution-wide directive and removes duplicate per-file lines.
In that case, literals in files that omitted the directive are frozen as well.
An explicit `false` uses Ruby's default; mixing `true` and `false` in one solution is rejected because a single bundled file cannot preserve both policies.
Because `__FILE__` and `__dir__` refer to the bundled file, avoid library implementations that access external files.
Self-tests guarded by `if __FILE__ == $PROGRAM_NAME` also run after bundling, so do not place them in library files.

`make doctor` checks library syntax and all bundling rules described above.
To inspect only library-related errors, run `bin/atcoder check-library`.

To generate a single file for manual submission at `abc468/a/submission.rb`, run:

```sh
bin/atcoder bundle abc468/a
# or
make bundle TARGET=abc468/a
```

`submission.rb` is excluded from Git tracking.
Running the command again updates only a `submission.rb` previously generated by this command.
The `submit` command also refreshes this file after all local tests pass.
If a manually created file with the same name already exists, the command stops instead of overwriting it.
Any direct edits to a generated `submission.rb` are lost the next time `bundle` or `submit` refreshes it.
Make changes in `main.rb` or `library/` instead.

A shorter summary of these layout rules is available in [library/README.md](library/README.md) (Japanese).

## Manual test cases

You can add local input and expected-output files to the regular test suite.
`INPUT` and `EXPECTED` must point to existing files.
Relative paths are resolved from the current directory, and absolute paths are also accepted.

```sh
bin/atcoder add-case abc468/a custom-1 input.txt expected.txt
```

This example creates `abc468/a/test/custom-1.in` and `custom-1.out`.
`NAME` may contain up to 64 characters.
It must start with a lowercase ASCII letter or digit, and the remaining characters may also include `_` and `-`.
Names in the reserved `sample-<number>` format are not allowed.
Existing files are never overwritten, so choose a different name if the case already exists.
The `.samples-complete` marker for official samples is not modified.

You may also directly place matching `test/<name>.in` and `test/<name>.out` files.
`bin/atcoder test` runs both official samples and manually added cases.

To add a case through Make, run:

```sh
make add-case TARGET=abc468/a NAME=custom-1 INPUT=input.txt EXPECTED=expected.txt
```

## Random testing

Random testing compares the oracle's output with the output from `main.rb` for the same generated input.
First, create a generator and oracle for the target problem:

```sh
bin/atcoder init-random abc468/a
```

This command creates the following two templates.
Running it again does not overwrite files you have edited.

- `random/generator.rb`: accepts a seed as its first argument and writes generated input to standard output
- `random/oracle.rb`: reads generated input from standard input and writes the expected output to standard output

The templates are intentionally incomplete and exit with status `1`.
Implement both files according to their comments before running random tests.

```sh
# Run 1,000 cases starting at seed 1.
bin/atcoder random abc468/a 1000 1

# Defaults to 100 cases starting at seed 1.
bin/atcoder random abc468/a
```

The same operations are available through Make:

```sh
make init-random TARGET=abc468/a
make random TARGET=abc468/a COUNT=1000 SEED=1
```

When an output mismatch or abnormal termination of `main.rb` occurs, the command saves the input, expected output, actual output, seed, and any standard error output under `random/failures/`.
Run the displayed `bin/atcoder random <TARGET> 1 <SEED>` command to reproduce the failure with the same seed.
After verifying the oracle's result, use the displayed `add-case` command to promote the failure to the regular regression suite.
Generated failure data is excluded from Git tracking.

Each process has a default timeout of 10 seconds and separate 16 MiB limits for standard output and standard error.
Change the timeout in seconds with a command such as `ATCODER_RANDOM_TIMEOUT=3 bin/atcoder random ...`.
If the generator or oracle terminates abnormally, the command exits with status `2` to distinguish infrastructure errors from solution failures.

Comparison normalizes only CRLF to LF; all other content must match exactly.
This exact comparison is not directly suitable for floating-point tolerances, multiple valid answers, output-only tasks, or problems with special judges.

The `submit` command reruns all local tests automatically, including official samples and manual cases.
After they pass, it saves the exact tested snapshot as `submission.rb`, copies it to the clipboard when a supported clipboard command is available, and opens AtCoder's submission page with the task preselected.

```sh
bin/atcoder submit abc468/a
```

In the browser, confirm Ruby 3.4.5 (language ID `6087`), paste or upload `submission.rb`, complete the human verification, and click Submit.
The command does not POST directly because AtCoder's Turnstile token must be generated and submitted by the browser.
If a browser or clipboard command is unavailable, the terminal prints the file path and submission URL instead.
Set `ATCODER_NO_BROWSER=1` or `ATCODER_NO_CLIPBOARD=1` to disable either automatic handoff.

The same operations are available through Make:

```sh
make tasks CONTEST=abc468
make contest CONTEST=abc468
make new CONTEST=abc468 TASK=a
make self-test
make add-case TARGET=abc468/a NAME=custom-1 INPUT=input.txt EXPECTED=expected.txt
make test TARGET=abc468/a
make run TARGET=abc468/a INPUT=input.txt
make bundle TARGET=abc468/a
make init-random TARGET=abc468/a
make random TARGET=abc468/a COUNT=1000 SEED=1
make submit TARGET=abc468/a
```

This workspace does not use `atcoder-cli` (`acc`).
The `tasks` and `contest` commands provide task listing and bulk creation of all contest problems without requiring global Ruby template configuration.

## Workspace self-tests

After modifying this workspace, run its regression tests with:

```sh
make self-test
```

The self-tests live under `test/`.
They use isolated temporary directories and fake external commands, so they do not modify problem files or require login or network access.
The suite covers library ordering, automatic bundling, manual `bundle`, random testing, browser-submission snapshots, clipboard/browser handoff, overwrite protection, source validation, login tool discovery, and OS-specific command selection.
GitHub Actions runs the same self-tests and the installed AtCoder parser compatibility check on both macOS and Ubuntu.
A separate Ubuntu x86_64 environment smoke workflow, available manually and on a monthly schedule, installs Ruby, builds all native gems, verifies LibTorch, and exercises every one of the 20 nonstandard gems.

## Differences from AtCoder

- Ruby is pinned to the same version used by AtCoder: 3.4.5.
- Syntax is checked with `ruby -c`, and samples run with `ruby --jit`.
- Every nonstandard gem listed directly by AtCoder is pinned to the same version.
- AtCoder does not publish versions for transitive gems. `Gemfile.lock` pins a compatible dependency snapshot available when the 2025-10 environment was published, but it cannot guarantee exact parity with every transitive gem on the judge.
- On macOS arm64, this workspace uses Homebrew native libraries and the macOS LibTorch build. AtCoder uses Linux x86_64, so the OS, CPU, and native builds differ; execution time, memory use, and some floating-point details may differ as well.
- The AtCoder API client is pinned to the exact commit from a [proposed upstream parser fix](https://github.com/online-judge-tools/api-client/pull/175) until a release supports `MiB` and `KiB` memory limits.
- AtCoder sets `RUBY_THREAD_VM_STACK_SIZE={memory:b}` from each problem's memory limit. Local commands do not set this problem-specific value automatically, so set the same value explicitly when testing deep recursion.
- Solutions that use gems unavailable on AtCoder will not run after submission. Prefer the standard library.

See AtCoder's [available languages and libraries](https://img.atcoder.jp/file/language-update/2025-10/language-list.html) for details about the target language environment.

## License

This project is licensed under the [MIT License](LICENSE).
