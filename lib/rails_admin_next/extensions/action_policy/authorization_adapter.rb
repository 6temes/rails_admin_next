# frozen_string_literal: true

module RailsAdminNext
  module Extensions
    module ActionPolicy
      # This adapter is for the ActionPolicy[https://github.com/palkan/action_policy] authorization
      # library. It responds to the same public methods as the Pundit adapter.
      class AuthorizationAdapter
        # Called each time +authorize_with :action_policy+ is configured. ActionPolicy is only
        # referenced from here and from method bodies, so hosts without the gem still boot.
        def self.setup
          include ::ActionPolicy::Behaviour

          authorize :user, through: -> { @controller._current_user }
        end

        # See the +authorize_with+ config method for where the initialization happens.
        def initialize(controller)
          @controller = controller
        end

        # Raises ActionPolicy::Unauthorized when the record's policy denies +action+. A record
        # with no policy, and a root action with no record, are checked against ApplicationPolicy.
        def authorize(action, abstract_model = nil, model_object = nil)
          return unless action

          record = model_object || abstract_model&.model
          authorize!(record, to: rule_for(action), with: policy_class_for(record))
          @controller.skip_verify_authorized! if @controller.respond_to?(:skip_verify_authorized!)
        end

        # Same check as +authorize+, returning a boolean instead of raising.
        def authorized?(action, abstract_model = nil, model_object = nil)
          return unless action

          record = model_object || abstract_model&.model
          allowed_to?(rule_for(action), record, with: policy_class_for(record))
        end

        # Scopes list, export, bulk delete and dashboard queries through the policy's default
        # relation scope. A model with no policy, no relation scope or only named ones gets no
        # records: bulk_delete deletes whatever this returns without a per-record check, so a
        # forgotten scope must not mean "everything".
        def query(_action, abstract_model)
          @controller.skip_verify_authorized_scoped! if @controller.respond_to?(:skip_verify_authorized_scoped!)
          authorized_scope(abstract_model.model.all, type: :active_record_relation)
        rescue ::ActionPolicy::NotFound, ::ActionPolicy::UnknownScopeType, ::ActionPolicy::UnknownNamedScope
          abstract_model.model.none
        end

        # Initial attributes for new records, from the policy's optional +attributes_for+ hook.
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
