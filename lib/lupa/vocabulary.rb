# frozen_string_literal: true

module Lupa
  # The method names lupa recognizes, grouped by what they mean. Every list is
  # explicit rather than pattern-matched, so lookalikes (after_sign_in_path_for)
  # never slip in. Tunable — err toward dropping.
  module Vocabulary
    CALL     = %w[call call!].freeze
    ENQUEUE  = %w[perform_later perform_async perform_now perform_in perform_at].freeze
    DELIVER  = %w[deliver_later deliver_now].freeze
    DYNAMIC  = %w[constantize safe_constantize].freeze
    MIXINS   = %w[include prepend extend].freeze

    ASSOCIATIONS = %w[has_many has_one belongs_to has_and_belongs_to_many].freeze
    COLLECTIONS  = %w[has_many has_and_belongs_to_many].freeze

    # ActiveRecord lifecycle callbacks. Each wires an event to a (same-class)
    # method, recorded as a `triggers` marker.
    CALLBACKS = %w[
      before_validation after_validation
      before_save around_save after_save after_save_commit
      before_create around_create after_create after_create_commit
      before_update around_update after_update after_update_commit
      before_destroy around_destroy after_destroy after_destroy_commit
      before_commit after_commit after_rollback
      after_initialize after_find after_touch
    ].freeze

    # The ActiveRecord *write* surface. On a model constant or an association
    # proxy these name a specific model being written — a `persists` edge.
    # `new`/`build` are construction, not a write, so they stay out.
    PERSIST = %w[
      create create! update update! update_all destroy destroy_all delete delete_all
      find_or_create_by find_or_create_by! first_or_create first_or_create!
      insert insert! insert_all upsert upsert_all save save!
    ].freeze

    # The ActiveRecord *read* surface — too ubiquitous to be useful edges.
    READ = %w[
      find find! find_by find_by! find_each find_in_batches where where! not
      all none first last second take pluck ids exists? any? many? count size sum
      average minimum maximum order reorder includes preload eager_load joins
      left_joins references select distinct group having limit offset unscoped
      from lock readonly find_or_initialize_by
    ].freeze

    # Constant-receiver methods never recorded as `invokes`: reads, writes
    # (recovered separately as `persists`) and construction. Recording them
    # would bury business-logic class-method calls under `Model.find` noise.
    NOISY = (READ + PERSIST + %w[new build]).freeze
  end
end
