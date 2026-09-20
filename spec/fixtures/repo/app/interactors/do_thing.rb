# frozen_string_literal: true

class DoThing
  include Interactor

  def call
    Widget.activate                 # invokes -> Widget (repo constant, kept)
    Thing.find(1)                   # noisy AR method -> dropped
    External::Api.summarize         # invokes but undefined in repo -> dropped
    handler_class.safe_constantize  # dispatches -> "handler_class" (runtime target)
    NotifyMailer.welcome(context.user).deliver_later # emails -> NotifyMailer (its .welcome invokes is suppressed)
    NotifyMailer.alert.deliver_now  # emails -> NotifyMailer (sync send, same rel)
    pending_mail.deliver_later      # deliver on a non-constant receiver -> dropped

    context.owner.widgets.create!(name: "x")  # persists -> Widget (unique association name)
    Widget.create!(name: "y")                 # persists -> Widget (class-level write on a model)
    context.owner.gizmos.create!              # `gizmos` is ambiguous (Widget/Owner) -> dropped
    context.owner.widgets.where(active: true) # a read, not a write -> no persists edge
    NotifyJob.create(payload: 1)              # write verb on a job constant -> filtered (not a model)
  end

  def handler_class
    "DoThing::#{context.kind}Handler"
  end
end
