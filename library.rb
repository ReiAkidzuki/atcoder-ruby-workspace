# frozen_string_literal: true

require_relative "bin/project_gem_environment"

program_path = File.expand_path($PROGRAM_NAME)
program_is_file =
  !%w[- -e].include?($PROGRAM_NAME) && File.file?(program_path)
if program_is_file
  AtCoderProjectGemEnvironment.activate!(program_path, ARGV)
else
  AtCoderProjectGemEnvironment.activate_in_process!
end

ATCODER_LIBRARY_LOADED = true unless defined?(ATCODER_LIBRARY_LOADED)

library_root = File.join(__dir__, "library")
common_dependencies =
  File.join(library_root, "00_core", "00_contest_dependencies.rb")
library_files = Dir.glob(File.join(library_root, "**", "*.rb"))
library_files
  .sort_by { |path| [path == common_dependencies ? 0 : 1, path] }
  .each { |path| require path }
