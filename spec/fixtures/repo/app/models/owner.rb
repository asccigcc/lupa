# frozen_string_literal: true

class Owner < ApplicationRecord
  # class_name wins over the naming convention: target is Widget, not "MainWidget".
  belongs_to :main_widget, class_name: "Widget", foreign_key: :widget_id
  # self-referential: target is Owner, not "Parent".
  belongs_to :parent, class_name: "Owner"
  # polymorphic has no single target -> dropped, not guessed.
  belongs_to :subject, polymorphic: true
end
