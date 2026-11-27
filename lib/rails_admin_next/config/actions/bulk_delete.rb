# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Actions
      class BulkDelete < RailsAdminNext::Config::Actions::Base
        RailsAdminNext::Config::Actions.register(self)

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          %i[post delete]
        end

        # Above this many records the confirmation states the count instead of listing each one.
        LIST_LIMIT = 100
        # Bounds the size of each destroy query, not the request: the whole set is still destroyed synchronously.
        SLICE_SIZE = 1_000

        register_instance_option :controller do
          proc do
            destroyable = ->(object) { @authorization_adapter.nil? || @authorization_adapter.authorized?(@action.authorization_key, @abstract_model, object) }
            empty_set_error = -> { t("admin.flash.error", name: pluralize(0, @model_config.label, plural: @model_config.label_plural), action: t("admin.actions.delete.done")) }

            # A query or filter on a has_many association eager-loads a join that repeats a record once
            # per matching associated row, so both the count and the keys are of distinct records.
            matching_count = lambda do
              count = list_entries(@model_config, :destroy).count(:all)
              count.is_a?(Hash) ? count.size : count
            end
            matching_keys = lambda do
              keys = list_entries(@model_config, :destroy).unscope(:order)
              keys = keys.eager_loading? ? keys.distinct : keys.unscope(:includes)
              keys.pluck(*Array(@abstract_model.model.primary_key).map { @abstract_model.model.arel_table[it] })
            end

            if request.post? # BULK DELETE
              if all_matching?
                @count = matching_count.call
              else
                @objects = list_entries(@model_config, :destroy).select(&destroyable)
                @count = @objects.size if @objects.size > LIST_LIMIT
              end

              if @count&.zero? || @objects&.empty?
                flash[:error] = empty_set_error.call
                redirect_to index_path
              else
                render @action.template_name
              end

            elsif request.delete? # BULK DESTROY
              destroyed = 0
              not_destroyed = 0
              # Rescue per record: dependent: :restrict_with_exception raises, and an
              # escaping raise would abandon every record behind it in the batch.
              # Audit inside the loop so any other raise still leaves a history row
              # for each record already destroyed.
              destroy = lambda do |object|
                next not_destroyed += 1 unless destroyable.call(object)

                object.destroy
                next not_destroyed += 1 unless object.destroyed?

                @auditing_adapter&.delete_object(object, @abstract_model, _current_user)
                destroyed += 1
              rescue ActiveRecord::DeleteRestrictionError
                not_destroyed += 1
              end

              keys = matching_keys.call if all_matching?
              if keys.present? && keys.size != params[:expected_count].to_i
                @count = keys.size
                flash.now[:notice] = t("admin.flash.bulk_delete_recount")
                render @action.template_name, status: :unprocessable_content
              else
                if keys
                  # Only the plucked keys are destroyed, so a record that starts matching meanwhile is left alone.
                  keys.each_slice(SLICE_SIZE) { @abstract_model.model.where(@abstract_model.model.primary_key => it).each(&destroy) }
                elsif params[:bulk_ids].present?
                  list_entries(@model_config, :destroy).each(&destroy)
                end

                if destroyed.zero? && not_destroyed.zero?
                  flash[:error] = empty_set_error.call
                else
                  flash[:success] = t("admin.flash.successful", name: pluralize(destroyed, @model_config.label, plural: @model_config.label_plural), action: t("admin.actions.delete.done")) unless destroyed.zero?
                  flash[:error] = t("admin.flash.error", name: pluralize(not_destroyed, @model_config.label, plural: @model_config.label_plural), action: t("admin.actions.delete.done")) unless not_destroyed.zero?
                end
                redirect_to back_or_index
              end
            end
          end
        end

        register_instance_option :all_matching? do
          true
        end

        register_instance_option :authorization_key do
          :destroy
        end

        register_instance_option :bulkable? do
          true
        end
      end
    end
  end
end
