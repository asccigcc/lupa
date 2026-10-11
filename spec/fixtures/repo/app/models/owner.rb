# frozen_string_literal: true

class Owner < ApplicationRecord
  # declares no scope on its own — Devise maps scopes in routes.rb, so reading
  # one off this class name would invent helpers the app doesn't have.
  devise :database_authenticatable, :lockable

  # class_name wins over the naming convention: target is Widget, not "MainWidget".
  belongs_to :main_widget, class_name: "Widget", foreign_key: :widget_id
  # self-referential: target is Owner, not "Parent".
  belongs_to :parent, class_name: "Owner"
  # polymorphic has no single target -> dropped, not guessed.
  belongs_to :subject, polymorphic: true
  # the other half of the ambiguous `gizmos` name (points to Owner, not Widget).
  has_many :gizmos, class_name: "Owner"
end
