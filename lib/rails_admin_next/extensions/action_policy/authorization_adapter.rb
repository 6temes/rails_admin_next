# frozen_string_literal: true

module RailsAdminNext
  module Extensions
    module ActionPolicy
      class AuthorizationAdapter
        # ActionPolicy is referenced only inside methods, so hosts without the gem still boot.
        def self.setup
          include ::ActionPolicy::Behaviour

          authorize :user, through: -> { @controller._current_user }
        end

        def initialize(controller)
          @controller = controller
        end

        def authorize(action, abstract_model = nil, model_object = nil)
          return unless action

          record = model_object || abstract_model&.model
          authorize!(record, to: rule_for(action), with: policy_class_for(record))
          @controller.skip_verify_authorized! if @controller.respond_to?(:skip_verify_authorized!)
        end

        def authorized?(action, abstract_model = nil, model_object = nil)
          return unless action

          record = model_object || abstract_model&.model
          allowed_to?(rule_for(action), record, with: policy_class_for(record))
        end

        def query(_action, abstract_model)
          @controller.skip_verify_authorized_scoped! if @controller.respond_to?(:skip_verify_authorized_scoped!)
          model = abstract_model.model
          authorized_scope(model.all, type: :active_record_relation, with: ::ActionPolicy.lookup(model))
        rescue ::ActionPolicy::NotFound, ::ActionPolicy::UnknownScopeType, ::ActionPolicy::UnknownNamedScope
          abstract_model.model.none
        end

        def attributes_for(action, abstract_model)
          record = abstract_model&.model
          policy_for(record:, with: policy_class_for(record)).try(:attributes_for, action) || {}
        end

        private

        def policy_class_for(record)
          ::ActionPolicy.lookup(record, default: ::ApplicationPolicy)
        end

        # A Symbol, because ActionPolicy keys its rule aliases (new? -> create?) by Symbol and a
        # String would silently skip them.
        def rule_for(action)
          action.to_s.end_with?("?") ? action.to_sym : :"#{action}?"
        end
      end
    end
  end
end
