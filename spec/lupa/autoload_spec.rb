# frozen_string_literal: true

RSpec.describe Lupa::Autoload do
  it "names the constant a file under an app/ root defines" do
    expect(described_class.constant_for("app/models/task.rb")).to eq("Task")
  end

  it "camelizes each path segment into a namespace" do
    expect(described_class.constant_for("app/interactors/task/configurator.rb")).to eq("Task::Configurator")
  end

  # Rails autoloads `app/*/concerns` as a root of its own, so the directory
  # name is not part of the constant.
  it "treats a concerns directory as a root rather than a namespace" do
    expect(described_class.constant_for("app/controllers/concerns/api/v1/base.rb")).to eq("Api::V1::Base")
  end

  it "names nothing for a file outside an app/ root" do
    expect(described_class.constant_for("config/routes.rb")).to be_nil
  end
end
