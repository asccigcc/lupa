# frozen_string_literal: true

RSpec.describe Lupa::RouteWalker do
  def routes(src)
    walker = described_class.new(file: "config/routes.rb")
    Prism.parse("Rails.application.routes.draw do\n#{src}\nend").value.accept(walker)
    walker.edges.map { |e| [e.src, e.dst] }
  end

  def labels(src) = routes(src).map(&:first)

  describe "resources" do
    it "expands a plural resource into its seven REST actions" do
      expect(routes("resources :widgets")).to all(include("WidgetsController"))
      expect(labels("resources :widgets"))
        .to eq(["GET /widgets #index", "POST /widgets #create", "GET /widgets/new #new",
                "GET /widgets/:id/edit #edit", "GET /widgets/:id #show", "PATCH /widgets/:id #update",
                "PUT /widgets/:id #update", "DELETE /widgets/:id #destroy"])
    end

    it "expands a singular resource without index or :id, to a plural controller" do
      expect(routes("resource :profile")).to all(include("ProfilesController"))
      expect(labels("resource :profile"))
        .to eq(["POST /profile #create", "GET /profile/new #new", "GET /profile/edit #edit", "GET /profile #show",
                "PATCH /profile #update", "PUT /profile #update", "DELETE /profile #destroy"])
    end

    it "honors only: and except:" do
      expect(labels("resources :widgets, only: [:index, :show]"))
        .to eq(["GET /widgets #index", "GET /widgets/:id #show"])
      expect(labels("resources :widgets, only: :show")).to eq(["GET /widgets/:id #show"])
      expect(labels("resources :widgets, except: %i[new edit update destroy create]"))
        .to eq(["GET /widgets #index", "GET /widgets/:id #show"])
    end

    it "honors controller:, path: and module:" do
      expect(routes("resources :parts, only: :index, controller: 'bits'"))
        .to eq([["GET /parts #index", "BitsController"]])
      expect(labels("resources :parts, only: :index, path: 'pieces'")).to eq(["GET /pieces #index"])
      expect(routes("resources :parts, only: :index, module: :shop"))
        .to eq([["GET /parts #index", "Shop::PartsController"]])
    end

    it "nests a child resource under the parent's :parent_id" do
      expect(routes("resources :patients, only: [] do\n  resources :orders, only: :show\nend"))
        .to eq([["GET /patients/:patient_id/orders/:id #show", "OrdersController"]])
    end

    it "routes member and collection blocks to the resource's controller" do
      src = "resources :widgets, only: [] do\n  member do\n    get :preview\n  end\n  " \
            "collection { post :import }\nend"
      expect(routes(src)).to eq([["GET /widgets/:id/preview #preview", "WidgetsController"],
                                 ["POST /widgets/import #import", "WidgetsController"]])
    end

    it "routes an on: option the same way" do
      src = "resources :widgets, only: [] do\n  get :preview, on: :member\n  get :search, on: :collection\nend"
      expect(labels(src))
        .to eq(["GET /widgets/:id/preview #preview", "GET /widgets/search #search"])
    end

    it "nests a bare verb inside a resource under :resource_id" do
      expect(routes("resources :prescriptions, only: [] do\n  get 'renew'\nend"))
        .to eq([["GET /prescriptions/:prescription_id/renew #renew", "PrescriptionsController"]])
    end

    it "keeps an explicit to: inside a resource" do
      expect(routes("resources :widgets, only: [] do\n  get 'x', to: 'pages#x', on: :collection\nend"))
        .to eq([["GET /widgets/x #x", "PagesController"]])
    end
  end

  it "routes verbs with to: and hash-rocket targets" do
    expect(routes("get 'a', to: 'pages#a'\npost 'b' => 'pages#b'"))
      .to eq([["GET /a #a", "PagesController"], ["POST /b #b", "PagesController"]])
  end

  it "routes root, inside a namespace too" do
    expect(routes("root to: 'pages#home'\nnamespace :admin do\n  root 'dashboards#show'\nend"))
      .to eq([["GET / #home", "PagesController"], ["GET /admin #show", "Admin::DashboardsController"]])
  end

  it "prefixes namespaces on module and path, scope module: on module only" do
    expect(routes("namespace :admin do\n  resources :users, only: :index\nend\n" \
                  "scope module: :api do\n  get 'x', to: 'v#x'\nend"))
      .to eq([["GET /admin/users #index", "Admin::UsersController"], ["GET /x #x", "Api::VController"]])
  end

  it "prefixes a positional or path: scope on the path only" do
    expect(labels("scope 'me' do\n  get 'x', to: 'v#x'\nend\nscope path: 'you' do\n  get 'y', to: 'v#y'\nend"))
      .to eq(["GET /me/x #x", "GET /you/y #y"])
  end

  it "ignores the module prefix for an absolute target" do
    expect(routes("namespace :admin do\n  get 'x', to: '/home#x'\nend")).to eq([["GET /admin/x #x", "HomeController"]])
  end

  it "routes devise controller overrides" do
    expect(routes("devise_for :patients, controllers: { sessions: 'patients/sessions' }"))
      .to eq([["DEVISE /patients/sessions", "Patients::SessionsController"]])
  end

  it "records the routes file on each edge" do
    walker = described_class.new(file: "config/routes/admin.rb")
    Prism.parse("get 'a', to: 'pages#a'").value.accept(walker)
    expect(walker.edges.map(&:file)).to eq(["config/routes/admin.rb"])
  end

  it "skips a verb without a controller target" do
    expect(routes("get 'health'")).to be_empty
  end
end
