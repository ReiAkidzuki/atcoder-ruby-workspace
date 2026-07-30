# frozen_string_literal: true

ATCODER_LIBRARY_LOADED = true unless defined?(ATCODER_LIBRARY_LOADED)

library_root = File.join(__dir__, "library")
Dir.glob(File.join(library_root, "**", "*.rb")).sort.each { |path| require path }
