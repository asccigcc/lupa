# frozen_string_literal: true

RSpec.describe Lupa::Extractor do
  subject(:result) { described_class.call(root: FIXTURE_REPO) }

  def edges(src: nil, rel: nil, dst: nil)
    result.edges.select do |e|
      (src.nil? || e.src == src) && (rel.nil? || e.rel == rel) && (dst.nil? || e.dst == dst)
    end
  end

  def node(name)
    result.nodes.find { |n| n.name == name }
  end

  describe "nodes" do
    it "records each defined class/module with an inferred kind" do
      expect(node("ThingsController").kind).to eq("controller")
      expect(node("DoThing").kind).to eq("interactor")
      expect(node("NotifyJob").kind).to eq("job")
      expect(node("Thing").kind).to eq("model")
      expect(node("Trackable").kind).to eq("concern")
    end

    it "captures the defining file and line" do
      thing = node("Thing")
      expect(thing.file).to eq("app/models/thing.rb")
      expect(thing.line).to eq(3)
    end

    it "namespaces nested constants" do
      expect(node("A::Dup")).not_to be_nil
      expect(node("Foo::DoThing").kind).to eq("interactor")
    end
  end

  describe "edges" do
    it "records Const.call as a `calls` edge" do
      expect(edges(src: "ThingsController", rel: "calls", dst: "DoThing")).not_to be_empty
    end

    it "records perform_later as an `enqueues` edge" do
      expect(edges(src: "ThingsController", rel: "enqueues", dst: "NotifyJob")).not_to be_empty
    end

    it "records organizer steps as `organizes` edges, one per step" do
      steps = edges(src: "Assemble", rel: "organizes").map(&:dst)
      expect(steps).to contain_exactly("DoThing", "DoOther")
    end

    it "records associations resolved by Rails naming convention" do
      assoc = edges(src: "Thing", rel: "association").map(&:dst)
      expect(assoc).to contain_exactly("Widget", "Owner")
    end

    it "honors an explicit class_name: over the naming convention" do
      # belongs_to :main_widget, class_name: "Widget" -> Widget, never "MainWidget".
      expect(edges(src: "Owner", rel: "association", dst: "Widget")).not_to be_empty
      expect(edges(src: "Owner", dst: "MainWidget")).to be_empty
    end

    it "resolves a self-referential class_name:" do
      expect(edges(src: "Owner", rel: "association", dst: "Owner")).not_to be_empty
    end

    it "drops a polymorphic association rather than guessing a target" do
      expect(edges(src: "Owner", dst: "Subject")).to be_empty
    end

    it "records concern includes" do
      expect(edges(src: "Thing", rel: "includes", dst: "Trackable")).not_to be_empty
    end

    it "records inheritance when the superclass is defined in the repo" do
      expect(edges(src: "ThingsController", rel: "inherits", dst: "ApplicationController")).not_to be_empty
      expect(edges(src: "NotifyJob", rel: "inherits", dst: "ApplicationJob")).not_to be_empty
    end

    it "records a non-noisy class-method call on a repo constant as `invokes`" do
      expect(edges(src: "DoThing", rel: "invokes", dst: "Widget")).not_to be_empty
    end

    it "does not record noisy ActiveRecord methods as `invokes`" do
      expect(edges(src: "DoThing", rel: "invokes", dst: "Thing")).to be_empty
    end

    it "drops an `invokes` whose receiver is not defined in the repo" do
      expect(edges(src: "DoThing", dst: "External::Api")).to be_empty
    end

    it "records constantize/safe_constantize as a `dispatches` marker keyed on the receiver" do
      dispatched = edges(src: "DoThing", rel: "dispatches").map(&:dst)
      expect(dispatched).to contain_exactly("handler_class")
    end

    it "records a mailer deliver_later/deliver_now as an `emails` edge to the mailer" do
      lines = edges(src: "DoThing", rel: "emails", dst: "NotifyMailer").map(&:line)
      expect(lines.size).to eq(2) # one deliver_later, one deliver_now
    end

    it "suppresses the redundant `invokes` for a delivered mailer action" do
      expect(edges(src: "DoThing", rel: "invokes", dst: "NotifyMailer")).to be_empty
    end

    it "drops a deliver whose receiver chain has no constant root" do
      expect(edges(src: "DoThing", rel: "emails").map(&:dst)).to all(eq("NotifyMailer"))
    end
  end

  describe "callbacks" do
    it "records a lifecycle callback's symbol target as a `triggers` marker" do
      expect(edges(src: "Thing", rel: "triggers").map(&:dst)).to include("notify_owner")
    end

    it "records one `triggers` edge per symbol when several are given" do
      expect(edges(src: "Thing", rel: "triggers").map(&:dst)).to include("normalize", "stamp")
    end

    it "keeps the symbol target verbatim — a method name, never resolved as a node" do
      expect(edges(src: "Thing", rel: "triggers", dst: "notify_owner")).not_to be_empty
      expect(node("notify_owner")).to be_nil
    end

    it "ignores the if:/unless: option, recording only the callback method" do
      triggered = edges(src: "Thing", rel: "triggers").map(&:dst)
      expect(triggered).to include("recount")
      expect(triggered).not_to include("changed?")
    end

    it "drops a block-form callback that names no method symbol" do
      expect(edges(src: "Thing", rel: "triggers").map(&:dst)).not_to include("cleanup")
    end
  end

  describe "routes" do
    it "records an explicit `to:` route as a `routes` edge to its controller" do
      srcs = edges(rel: "routes", dst: "ThingsController").map(&:src)
      expect(srcs).to include("GET /things", "POST /things/bulk")
    end

    it "resolves the hash-rocket (verb => target) form" do
      expect(edges(src: "GET /up", rel: "routes", dst: "ThingsController")).not_to be_empty
    end

    it "camelizes a namespaced controller path from devise_for" do
      expect(edges(rel: "routes", dst: "Patients::RegistrationsController")).not_to be_empty
    end

    it "maps a resource inside a namespace to the prefixed controller" do
      expect(edges(rel: "routes", dst: "Admin::WidgetsController")).not_to be_empty
    end

    it "prefixes the controller module from `scope module:`" do
      expect(edges(src: "PATCH /widgets/sync", rel: "routes", dst: "Admin::WidgetsController")).not_to be_empty
    end

    it "treats a leading-slash `to:` as absolute, ignoring the module scope" do
      expect(edges(src: "GET /abs", rel: "routes", dst: "ThingsController")).not_to be_empty
    end

    it "pluralizes a singular resource to name its controller" do
      expect(edges(src: "RESOURCE /thing", rel: "routes", dst: "ThingsController")).not_to be_empty
    end

    it "honors an explicit controller: override on a resource" do
      expect(edges(src: "RESOURCES /gadgets", rel: "routes", dst: "ThingsController")).not_to be_empty
    end

    it "records the route itself as a node of kind route" do
      expect(node("GET /things").kind).to eq("route")
    end

    it "drops a route whose controller is not defined in the repo" do
      expect(edges(rel: "routes", dst: "External::ApiController")).to be_empty
    end
  end

  describe "resolution" do
    it "prefers an exact full-name match over an ambiguous short name" do
      # `DoThing` is also defined as Foo::DoThing, but the top-level call resolves
      # to the exact match, never to the namespaced one.
      targets = edges(src: "ThingsController", rel: "calls").map(&:dst)
      expect(targets).to include("DoThing")
      expect(targets).not_to include("Foo::DoThing")
    end

    it "drops a call whose constant is not defined in the repo" do
      expect(edges(src: "ThingsController", dst: "External::Api")).to be_empty
    end

    it "drops an ambiguous short name with no exact match" do
      # Caller references bare `Dup`, defined as both A::Dup and B::Dup.
      expect(edges(src: "Caller")).to be_empty
    end
  end
end
