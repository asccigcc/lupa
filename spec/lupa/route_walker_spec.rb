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

  describe "verbs without to:" do
    it "route to the enclosing namespace's controller" do
      expect(routes("namespace :formsort do\n  post 'answers'\nend\n" \
                    "namespace :providers do\n  namespace :work_shifts do\n    post :toggle\n  end\nend"))
        .to eq([["POST /formsort/answers #answers", "FormsortController"],
                ["POST /providers/work_shifts/toggle #toggle", "Providers::WorkShiftsController"]])
    end

    it "read a slashed path as controller/action" do
      expect(routes("post 'stripe/update'\npost '/x/y/z'\nget 'dash-ed/thing-x'"))
        .to eq([["POST /stripe/update #update", "StripeController"], ["POST /x/y/z #z", "X::YController"],
                ["GET /dash-ed/thing-x #thing_x", "DashEdController"]])
    end

    it "record one route per action when a call lists several" do
      expect(labels("resource :insurance, only: [] do\n  collection do\n    get :card, :info\n  end\nend"))
        .to eq(["GET /insurance/card #card", "GET /insurance/info #info"])
    end

    it "honor action: and controller:" do
      expect(routes("namespace :ic do\n  post 'pb', controller: '/intercom', action: :cps\nend\n" \
                    "get 'ctl', controller: :foo\n" \
                    "resource :renewal_payment, only: [] do\n  get :setup_intent, action: :card_setup_intent\nend"))
        .to eq([["POST /ic/pb #cps", "IntercomController"], ["GET /ctl #ctl", "FooController"],
                ["GET /renewal_payment/setup_intent #card_setup_intent", "RenewalPaymentsController"]])
    end

    it "use the controller set by scope controller: or a controller block" do
      expect(routes("scope controller: :pages do\n  get 'about'\nend\ncontroller :help do\n  get 'faq'\nend"))
        .to eq([["GET /about #about", "PagesController"], ["GET /faq #faq", "HelpController"]])
    end

    it "keep the resource's controller inside a nested namespace or scope module:" do
      expect(routes("resources :orders, only: [] do\n  scope module: :orders do\n    " \
                    "resource :product_category, only: :update\n  end\nend"))
        .to eq([["PATCH /orders/:order_id/product_category #update", "Orders::ProductCategoriesController"],
                ["PUT /orders/:order_id/product_category #update", "Orders::ProductCategoriesController"]])
    end
  end

  it "drops a verb whose to: is not a controller#action (redirect, proc, rack app)" do
    expect(routes("namespace :admin do\n  get 'foo', to: redirect('/bar')\n  " \
                  "get 'pr', to: proc { [204, {}, []] }\nend")).to be_empty
  end

  it "ignores a concern's body, which only becomes routes where concerns: names it" do
    expect(routes("namespace :shop do\n  concern :commentable do\n    get 'comments'\n  end\nend")).to be_empty
  end

  describe "root" do
    it "honors controller: and action:" do
      expect(routes("namespace :pnv do\n  root controller: '/phone_number_verifications', action: :new\nend"))
        .to eq([["GET /pnv #new", "PhoneNumberVerificationsController"]])
    end

    it "is dropped when it redirects instead of naming a controller" do
      expect(routes("namespace :dev do\n  root to: redirect('/api-docs')\nend")).to be_empty
    end
  end

  it "records a match route once per via: verb" do
    expect(labels("match 'sig', to: 'info#sig', via: [:get, :post]\nmatch 'all', to: 'info#all', via: :all"))
      .to eq(["GET /sig #sig", "POST /sig #sig", "ANY /all #all"])
  end

  it "prefixes an engine's own draw block with the engine's module" do
    walker = described_class.new(file: "config/routes.rb")
    Prism.parse("Shop::Engine.routes.draw do\n  resources :carts, only: :index\nend").value.accept(walker)
    expect(walker.edges.map { |e| [e.src, e.dst] }).to eq([["GET /carts #index", "Shop::CartsController"]])
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
