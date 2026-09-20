# frozen_string_literal: true

RSpec.describe Lupa::Repo do
  it "expands the given path to an absolute root" do
    expect(described_class.new("spec/fixtures/repo").root).to eq(FIXTURE_REPO)
  end

  it "defaults the root to the current directory" do
    Dir.chdir(FIXTURE_REPO) { expect(described_class.new.root).to eq(FIXTURE_REPO) }
  end

  it "locates the graph db under the root" do
    expect(described_class.new("/tmp/example").db).to eq("/tmp/example/tmp/lupa.db")
  end
end
