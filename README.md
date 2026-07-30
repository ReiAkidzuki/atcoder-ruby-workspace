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

This workspace supports macOS and Linux.
On Windows, use WSL.

Install [rbenv](https://github.com/rbenv/rbenv), [ruby-build](https://github.com/rbenv/ruby-build), and [uv](https://docs.astral.sh/uv/getting-started/installation/) first.
On macOS, you can install them with Homebrew:

```sh
brew install rbenv ruby-build uv
rbenv init
```

After running `rbenv init`, follow its instructions and restart your terminal.

On Linux, install the [build environment recommended by ruby-build](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment) and the `time` package that provides GNU time.
Then install rbenv and uv according to their official instructions, and run `rbenv init`.

After cloning the repository, run:

```sh
make setup
make doctor
make self-test
```

`make setup` installs Ruby 3.4.5, online-judge-tools (`oj`), and the AtCoder login helper (`aclogin`).
On macOS, it also installs GNU time with Homebrew when necessary.
When every item reported by `make doctor` is `ok`, the local environment is ready.
`make self-test` runs the workspace's regression tests in a temporary directory without making network requests.

## First-time login for submissions

Because AtCoder uses CAPTCHA, the CLI cannot complete an automated login on its own.
Log in to AtCoder in a browser, copy the value of the `REVEL_SESSION` cookie from the browser's developer tools, and then run:

```sh
make login
```

Paste the cookie value into the prompt.
The cookie is stored in `oj`'s user data directory and is never stored in this repository.
Do not paste the cookie value into source code, commits, or chats.
Normally, only submissions require login.
Public task listings, problem scaffolding, sample downloads, and local tests usually work without it.
If sample download is rejected because authentication is required, run `make login`.

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
For submission, `oj` sends the exact temporary file that passed all local tests, including official samples and manual cases.
A newly generated `main.rb` also loads libraries from the project root when run directly.
A `main.rb` not based on the current template may not load libraries when invoked directly with `ruby`; `bin/atcoder run` always creates the bundle first.

Libraries may load standard-library files, for example with `require "set"`.
`require_relative` is rejected during bundling in both `main.rb` and library files because its meaning changes after files are combined.
`__END__` and `DATA` are also unavailable in library files.
Save `main.rb` and every library as UTF-8, and place `# frozen_string_literal: true` before executable code.
Normally, put it on the first line.
Frozen string literals are enabled for the complete bundled solution.
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
If a manually created file with the same name already exists, the command stops instead of overwriting it.
Any direct edits to a generated `submission.rb` are lost the next time it is bundled.
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
Only after they pass does it proceed to confirmation and submit as Ruby 3.4.5 (language ID `6087`).

```sh
bin/atcoder submit abc468/a
```

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
The suite covers library ordering, automatic bundling, manual `bundle`, random testing, submission snapshots, overwrite protection, source validation, login tool discovery, and OS-specific command selection.
GitHub Actions runs the same self-tests on both macOS and Ubuntu.

## Differences from AtCoder

- Ruby is pinned to the same version used by AtCoder: 3.4.5.
- Syntax is checked with `ruby -c`, and samples run with `ruby --jit`.
- Local execution time and memory usage do not exactly match AtCoder's production environment.
- For deep recursion, set `RUBY_THREAD_VM_STACK_SIZE` as necessary for the problem's memory limit.
- Solutions that use gems unavailable on AtCoder will not run after submission. Prefer the standard library.

See AtCoder's [available languages and libraries](https://img.atcoder.jp/file/language-update/2025-10/language-list.html) for details about the target language environment.

## License

This project is licensed under the [MIT License](LICENSE).
