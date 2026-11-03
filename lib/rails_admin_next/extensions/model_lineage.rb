# frozen_string_literal: true

module RailsAdminNext
  module Extensions
    # Pundit and ActionPolicy look a policy up by the record's own class name only, so without
    # walking these an STI subclass with no policy skips its parent model's for ApplicationPolicy.
    module ModelLineage
      def self.superclasses(record)
        model = record.is_a?(Class) ? record : record.class
        model.ancestors.grep(Class).drop(1).take_while { it < ::ActiveRecord::Base && !it.abstract_class? }
      end
    end
  end
end
