# frozen_string_literal: true

RSpec.describe Lupa::Integrations::Devise do
  def scope(name:, model:)
    Lupa::Integrations::Devise::Scope.new(name:, model:)
  end

  def walk(src, file: "app/controllers/things_controller.rb")
    Lupa::Walker.new(file:).tap { |walker| Prism.parse(src).value.accept(walker) }
  end

  def draw(src)
    Lupa::RouteWalker.new(file: "config/routes.rb")
                     .tap { |walker| Prism.parse("Rails.application.routes.draw do\n#{src}\nend").value.accept(walker) }
  end

  # The wrapper class brings an `inherits` edge of its own, so assertions here
  # look only at what the filter recognizer contributed.
  def auth_edges(body)
    walk("class ThingsController < ApplicationController\n#{body}\nend")
      .edges.select { _1.rel == "authenticates" }
  end

  describe "devise_for, the only place a scope is declared" do
    it "declares the scope in the singular, as Devise names it" do
      expect(draw("devise_for :patients").declarations).to eq([scope(name: "patient", model: "Patient")])
    end

    it "honors class_name: for a scope mounted onto another model" do
      expect(draw("devise_for :otc, class_name: 'Patient'").declarations.map { [_1.name, _1.model] })
        .to eq([%w[otc Patient]])
    end

    it "camelizes a multi-word scope into its model" do
      expect(draw("devise_for :pharmacy_users").declarations.map(&:model)).to eq(["PharmacyUser"])
    end

    it "still records the controllers: overrides" do
      walker = draw("devise_for :patients, controllers: { sessions: 'patients/sessions' }")
      expect(walker.edges.map { [_1.src, _1.dst] }).to eq([["DEVISE /patients/sessions", "Patients::SessionsController"]])
    end

    it "ignores a model's own devise call, which declares no scope" do
      # Devise.add_mapping — and so every helper name — comes from `devise_for`.
      # The model's `devise` only includes modules, so reading a scope off the
      # class name would invent `current_user` for `devise_for :members`.
      expect(walk("class User < ApplicationRecord\n  devise :lockable\nend").declarations).to be_empty
    end
  end

  describe "the names a scope resolves through" do
    it "maps both the record accessor and the auth filter to the model" do
      expect(scope(name: "patient", model: "Patient").accessors)
        .to eq([%w[current_patient Patient Patient], %w[authenticate_patient! Patient Patient]])
    end
  end

  describe "before_action :authenticate_<scope>!" do
    it "records an `authenticates` edge naming the helper" do
      expect(auth_edges("  before_action :authenticate_patient!").map { [_1.src, _1.rel, _1.dst] })
        .to eq([["ThingsController", "authenticates", "authenticate_patient!"]])
    end

    it "records the prepend/append variants too" do
      body = "  prepend_before_action :authenticate_patient!\n  append_before_action :authenticate_admin!"
      expect(auth_edges(body).map(&:dst)).to eq(%w[authenticate_patient! authenticate_admin!])
    end

    it "ignores skip_before_action, which exempts rather than requires" do
      src = "  skip_before_action :authenticate_patient!, only: %i[sso]"
      expect(auth_edges(src)).to be_empty
    end

    it "reads only the positional symbols, never the only:/except: action names" do
      src = "  before_action :authenticate_patient!, only: %i[authenticate_admin!]"
      expect(auth_edges(src).map(&:dst)).to eq(["authenticate_patient!"])
    end

    it "leaves a filter that demands no devise scope alone" do
      expect(auth_edges("  before_action :set_thing")).to be_empty
    end
  end

  it "declares nothing in an app that doesn't use devise" do
    expect(walk("class Thing < ApplicationRecord\n  has_many :widgets\nend").declarations).to be_empty
  end

  # An app can define `current_patient` and `authenticate_patient!` itself, with
  # no Devise anywhere. Nothing here may be attributed to the gem, so the whole
  # integration has to stay inert on a repo that never says `devise_for`.
  describe "an app that uses the names but not the gem" do
    subject(:result) { Lupa::Extractor.call(root: PLAIN_REPO) }

    it "sees the controller and the model" do
      expect(result.nodes.map(&:name)).to include("ApplicationController", "Patient")
    end

    it "records no `authenticates` edge for a hand-written filter" do
      expect(result.edges.select { _1.rel == "authenticates" }).to be_empty
    end

    it "records no write through a hand-written current_patient" do
      expect(result.edges.select { _1.rel == "persists" }).to be_empty
    end
  end
end
