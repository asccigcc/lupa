# frozen_string_literal: true

RSpec.describe Lupa::Integrations::Devise do
  def scope(name:, model:, modules: [])
    Lupa::Integrations::Devise::Scope.new(name:, model:, modules:)
  end

  def walk(src, file: "app/models/patient.rb")
    Lupa::Walker.new(file:).tap { |walker| Prism.parse(src).value.accept(walker) }
  end

  def draw(src)
    Lupa::RouteWalker.new(file: "config/routes.rb")
                     .tap { |walker| Prism.parse("Rails.application.routes.draw do\n#{src}\nend").value.accept(walker) }
  end

  describe "a model's own devise call" do
    it "names the scope after the model and keeps the modules the routes depend on" do
      declared = walk("class Patient < ApplicationRecord\n  devise :confirmable, :lockable\nend").declarations
      expect(declared).to eq([scope(name: "patient", model: "Patient", modules: %w[confirmable lockable])])
    end

    it "underscores a multi-word model, as Devise names the scope" do
      expect(walk("class PharmacyUser < ApplicationRecord\n  devise :lockable\nend").declarations.map(&:name))
        .to eq(["pharmacy_user"])
    end

    it "declares each call, since one model may call devise more than once" do
      src = "class PharmacyUser < ApplicationRecord\n  devise :lockable\n  devise :two_factor_authenticatable\nend"
      expect(walk(src).declarations.map(&:modules)).to eq([["lockable"], ["two_factor_authenticatable"]])
    end
  end

  describe "devise_for" do
    it "declares the scope in the singular, as Devise names it" do
      expect(draw("devise_for :patients").declarations).to eq([scope(name: "patient", model: "Patient")])
    end

    it "honors class_name: for a scope mounted onto another model" do
      expect(draw("devise_for :otc, class_name: 'Patient'").declarations.map { [_1.name, _1.model] })
        .to eq([%w[otc Patient]])
    end

    it "still records the controllers: overrides" do
      walker = draw("devise_for :patients, controllers: { sessions: 'patients/sessions' }")
      expect(walker.edges.map { [_1.src, _1.dst] }).to eq([["DEVISE /patients/sessions", "Patients::SessionsController"]])
    end
  end

  describe "the accessors a scope generates" do
    it "maps the record accessor to the scope's model, owned by it" do
      expect(scope(name: "patient", model: "Patient").accessors)
        .to eq([%w[current_patient Patient Patient]])
    end
  end

  it "declares nothing in an app that doesn't use devise" do
    expect(walk("class Thing < ApplicationRecord\n  has_many :widgets\nend").declarations).to be_empty
  end
end
