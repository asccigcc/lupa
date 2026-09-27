# frozen_string_literal: true

RSpec.describe Lupa::RouteWalker do
  def routes(src)
    walker = described_class.new(file: "config/routes.rb")
    Prism.parse("Rails.application.routes.draw do\n#{src}\nend").value.accept(walker)
    walker.edges.map { |e| [e.src, e.dst] }
  end

  it "routes resources, singular resources and controller overrides" do
    expect(routes("resources :widgets\nresource :profile\nresources :parts, controller: 'bits'"))
      .to eq([["RESOURCES /widgets", "WidgetsController"], ["RESOURCE /profile", "ProfilesController"],
              ["RESOURCES /parts", "BitsController"]])
  end

  it "routes verbs with to: and hash-rocket targets" do
    expect(routes("get 'a', to: 'pages#a'\npost 'b' => 'pages#b'"))
      .to eq([["GET /a", "PagesController"], ["POST /b", "PagesController"]])
  end

  it "prefixes namespaces on module and path, scope module: on module only" do
    expect(routes("namespace :admin do\n  resources :users\nend\nscope module: :api do\n  get 'x', to: 'v#x'\nend"))
      .to eq([["RESOURCES /admin/users", "Admin::UsersController"], ["GET /x", "Api::VController"]])
  end

  it "ignores the module prefix for an absolute target" do
    expect(routes("namespace :admin do\n  get 'x', to: '/home#x'\nend")).to eq([["GET /admin/x", "HomeController"]])
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
