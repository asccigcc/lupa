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
  end

  def handler_class
    "DoThing::#{context.kind}Handler"
  end
end
