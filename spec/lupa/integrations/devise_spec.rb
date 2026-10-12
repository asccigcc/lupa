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
      expect(draw("devise_for :staff_members").declarations.map(&:model)).to eq(["StaffMember"])
    end

    it "ignores a model's own devise call, which declares no scope" do
      # Devise.add_mapping — and so every helper name — comes from `devise_for`.
      # The model's `devise` only includes modules, so reading a scope off the
      # class name would invent `current_user` for `devise_for :members`.
      expect(walk("class User < ApplicationRecord\n  devise :lockable\nend").declarations).to be_empty
    end
  end

  # The expected paths here are Devise 5.0.4's own, read off
  # `lib/devise/rails/routes.rb` and `lib/devise/mapping.rb`.
  describe "the routes a devise_for mount generates" do
    def routes(src)
      draw(src).edges.map { [_1.src, _1.dst] }
    end

    def labels(src)
      routes(src).map(&:first)
    end

    it "expands sessions into the three routes Devise declares, in its order" do
      expect(routes("devise_for :admins, controllers: { sessions: 'admins/sessions' }")).to eq(
        [["GET /admins/sign_in #new", "Admins::SessionsController"],
         ["POST /admins/sign_in #create", "Admins::SessionsController"],
         ["DELETE /admins/sign_out #destroy", "Admins::SessionsController"]]
      )
    end

    it "mounts at the root when path: is empty, which is where Devise puts it" do
      src = "devise_for :patients, path: '', controllers: { sessions: 'patients/sessions' }"
      expect(labels(src)).to eq(["GET /sign_in #new", "POST /sign_in #create", "DELETE /sign_out #destroy"])
    end

    it "honors a path: that differs from the mount name" do
      src = "devise_for :otc, path: 'over_the_counter', controllers: { sessions: 'otc/sessions' }"
      expect(labels(src).first).to eq("GET /over_the_counter/sign_in #new")
    end

    it "renames a segment that path_names: overrides" do
      src = "devise_for :admins, path_names: { sign_in: 'login', sign_out: 'logout' }, " \
            "controllers: { sessions: 'admins/sessions' }"
      expect(labels(src)).to eq(["GET /admins/login #new", "POST /admins/login #create",
                                 "DELETE /admins/logout #destroy"])
    end

    it "expands passwords as the singular resource it is" do
      expect(labels("devise_for :admins, controllers: { passwords: 'admins/passwords' }")).to contain_exactly(
        "GET /admins/password/new #new", "POST /admins/password #create",
        "GET /admins/password/edit #edit", "PATCH /admins/password #update", "PUT /admins/password #update"
      )
    end

    it "gives confirmations a show route rather than an edit one" do
      expect(labels("devise_for :admins, controllers: { confirmations: 'admins/confirmations' }")).to contain_exactly(
        "GET /admins/confirmation/new #new", "POST /admins/confirmation #create",
        "GET /admins/confirmation #show"
      )
    end

    it "expands unlocks the same shape as confirmations" do
      expect(labels("devise_for :admins, controllers: { unlocks: 'admins/unlocks' }")).to contain_exactly(
        "GET /admins/unlock/new #new", "POST /admins/unlock #create", "GET /admins/unlock #show"
      )
    end

    # path_names[:registration] defaults to "", so registrations hang off the
    # mount root: POST /admins, not POST /admins/registration.
    it "mounts registrations at the scope root, since its path_name defaults to empty" do
      expect(labels("devise_for :admins, controllers: { registrations: 'admins/registrations' }")).to contain_exactly(
        "GET /admins/sign_up #new", "POST /admins #create", "GET /admins/edit #edit",
        "PATCH /admins #update", "PUT /admins #update", "DELETE /admins #destroy",
        "GET /admins/cancel #cancel"
      )
    end

    it "labels the routes with an enclosing scope's path prefix" do
      src = "scope 'staff' do\n  devise_for :admins, controllers: { sessions: 'admins/sessions' }\nend"
      expect(labels(src).first).to eq("GET /staff/admins/sign_in #new")
    end

    describe "roles it does not expand" do
      it "records nothing for a controller Devise itself owns" do
        # No controllers: override means devise/sessions, which is not in the repo.
        expect(routes("devise_for :admins")).to be_empty
      end

      it "drops a role the mount skips" do
        src = "devise_for :otc, skip: [:registrations], controllers: { registrations: 'otc/registrations' }"
        expect(routes(src)).to be_empty
      end

      it "drops every role when skip: :all" do
        src = "devise_for :admins, skip: :all, controllers: { sessions: 'admins/sessions' }"
        expect(routes(src)).to be_empty
      end

      it "keeps only the roles only: names" do
        src = "devise_for :admins, only: [:sessions], " \
              "controllers: { sessions: 'admins/sessions', passwords: 'admins/passwords' }"
        expect(labels(src)).to all(include("sign_in").or(include("sign_out")))
      end

      # Devise builds these paths from the model's `omniauth_providers`, which a
      # routes file cannot see. Only the prefix is knowable, so the controller
      # stays reachable through a marker instead of an invented URL.
      it "records only a prefix marker for omniauth_callbacks" do
        src = "devise_for :patients, controllers: { omniauth_callbacks: 'patients/omniauth_callbacks' }"
        expect(routes(src)).to eq([["DEVISE /patients/auth", "Patients::OmniauthCallbacksController"]])
      end
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
