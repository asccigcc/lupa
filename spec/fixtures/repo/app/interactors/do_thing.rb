# frozen_string_literal: true

class DoThing
  include Interactor

  def call
    Widget.activate                 # invokes -> Widget (repo constant, kept)
    Thing.find(1)                   # noisy AR method -> dropped
    External::Api.summarize         # invokes but undefined in repo -> dropped
    handler_class.safe_constantize  # dispatches -> "handler_class" (runtime target)
  end

  def handler_class
    "DoThing::#{context.kind}Handler"
  end
end
