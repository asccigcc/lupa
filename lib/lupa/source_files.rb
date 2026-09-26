# frozen_string_literal: true

module Lupa
  # Which files of a repo lupa reads: Ruby under app/ (or the whole repo when
  # there is no app/), plus the Rails route files, which live outside app/.
  class SourceFiles
    SKIP = %r{/(vendor|node_modules|tmp|\.git|db/migrate|spec|test)/}

    attr_reader :root, :scan_dir

    # @param root [String] repo root, relative or absolute
    def initialize(root)
      @root = File.expand_path(root)
      app = File.join(@root, "app")
      @scan_dir = File.directory?(app) ? app : @root
    end

    # SKIP is matched against the repo-relative path so the tool's own location
    # (a checkout living under some .../spec/ tree) can't skip a target.
    # Sorted by full path so `claims/sync.rb` precedes `claims/sync/*.rb` (glob's
    # own per-directory order doesn't): the first definition seen names a node's file.
    # @return [Array<String>] absolute paths
    def ruby_files
      Dir.glob(File.join(scan_dir, "**", "*.rb")).sort # rubocop:disable Lint/RedundantDirGlobSort
         .reject { |path| "/#{relative(path)}".match?(SKIP) }
    end

    # @return [Array<String>] config/routes.rb plus any config/routes/*.rb split files
    def route_files
      main = File.join(root, "config", "routes.rb")
      (File.file?(main) ? [main] : []) + Dir.glob(File.join(root, "config", "routes", "*.rb"))
    end

    # @return [String] path relative to the repo root
    def relative(path)
      path.delete_prefix("#{root}/")
    end

    # @return [String] what was scanned, for display, e.g. "app"
    def label
      relative(scan_dir)
    end
  end
end
