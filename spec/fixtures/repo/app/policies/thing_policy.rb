# frozen_string_literal: true

# Pundit's idiom: the superclass `Scope` is read before ThingPolicy::Scope
# exists, so Ruby finds it through ThingPolicy's ancestors.
class ThingPolicy < ApplicationPolicy
  class Scope < Scope
  end
end
