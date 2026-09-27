# frozen_string_literal: true

require "stringio"
require "tmpdir"

RSpec.describe Lupa::CLI do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  def run(*argv)
    described_class.new(argv, out:, err:).run
  end

  around do |example|
    Dir.mktmpdir do |dir|
      %w[app config].each { |sub| FileUtils.cp_r(File.join(FIXTURE_REPO, sub), dir) }
      Dir.chdir(dir) { example.run }
    end
  end

  describe "without a graph" do
    it "prints usage for help" do
      expect(run("help")).to eq(0)
      expect(out.string).to include("lupa scan [PATH]")
    end

    it "rejects an unknown command" do
      expect(run("frobnicate")).to eq(1)
      expect(err.string).to include('unknown command "frobnicate"')
    end

    it "asks for a scan before querying" do
      expect(run("callers", "Widget")).to eq(1)
      expect(err.string).to include("run 'lupa scan'")
    end
  end

  describe "with a scanned graph", if: system("command -v sqlite3 >/dev/null 2>&1") do
    before { run("scan") }

    it "reports what it scanned, including unparseable files" do
      expect(out.string).to include("lupa: scanned app — nodes=", "skipped 1 unparseable: app/models/broken.rb")
      expect(File).to exist("tmp/lupa.db")
    end

    it "answers callers, calls and where through the injected output" do
      run("callers", "DoThing")
      run("calls", "ThingsController")
      run("where", "Thing")
      expect(out.string).to include("ThingsController", "calls", "app/models/thing.rb")
    end

    it "shows the impact radius in both directions with file:line" do
      run("impact", "DoThing")
      expect(out.string).to include("in ", "ThingsController", "app/controllers/things_controller.rb:", "out", "Widget")
    end

    it "prints the shortest chain between two classes" do
      run("path", "ThingsController", "NotifyMailer")
      expect(out.string).to include("ThingsController -calls-> DoThing -emails-> NotifyMailer")
    end

    it "says so when no chain connects them" do
      expect(run("path", "NotifyMailer", "ThingsController")).to eq(0)
      expect(out.string).to include("no path from NotifyMailer to ThingsController")
    end

    it "prints stats by kind and rel" do
      run("stats")
      expect(out.string).to include("nodes by kind:", "edges by rel:", "persists")
    end

    it "requires a name argument" do
      expect(run("callers")).to eq(1)
      expect(err.string).to include("needs a name argument")
    end

    it "surfaces a sqlite3 error" do
      expect(run("query", "SELECT nope FROM nowhere;")).to eq(1)
      expect(err.string).to include("sqlite3 failed")
    end
  end
end
