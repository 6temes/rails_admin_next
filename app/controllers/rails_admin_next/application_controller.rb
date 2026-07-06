# frozen_string_literal: true

require "rails_admin_next/abstract_model"

module RailsAdminNext
  class ModelNotFound < ::StandardError
  end

  class ObjectNotFound < ::StandardError
  end

  class ActionNotAllowed < ::StandardError
  end

  class ApplicationController < Config.parent_controller.constantize
    include RailsAdminNext::Extensions::ControllerExtension

    protect_from_forgery(with: :exception)

    before_action :_set_security_headers
    before_action :_authenticate!
    before_action :_authorize!
    before_action :_audit!

    helper_method :_current_user

    attr_reader :object, :model_config, :abstract_model, :authorization_adapter

    def get_model
      @model_name = to_model_name(params[:model_name])
      raise RailsAdminNext::ModelNotFound unless (@abstract_model = RailsAdminNext::AbstractModel.new(@model_name))
      raise RailsAdminNext::ModelNotFound if (@model_config = @abstract_model.config).excluded?

      @properties = @abstract_model.properties
    end

    def get_object
      raise RailsAdminNext::ObjectNotFound unless (@object = @abstract_model.get(params[:id], @model_config.scope))
    end

    def to_model_name(param)
      param.split("~").collect(&:camelize).join("::")
    end

    def _current_user
      instance_eval(&RailsAdminNext::Config.current_user_method)
    end

    private

    # The admin is a privileged surface: always advertise SAMEORIGIN framing, and apply the
    # host-opted-in Content Security Policy (with a per-request nonce for the engine's inline
    # tags) per-request so it covers only admin responses, never the host app.
    def _set_security_headers
      response.headers["X-Frame-Options"] = "SAMEORIGIN"

      policy_block = RailsAdminNext::Config.content_security_policy
      return unless policy_block

      policy = ActionDispatch::ContentSecurityPolicy.new
      policy_block.call(policy)
      request.content_security_policy = policy
      request.content_security_policy_report_only = RailsAdminNext::Config.content_security_policy_report_only
      request.content_security_policy_nonce_generator ||= ->(_request) { SecureRandom.base64(16) }
      request.content_security_policy_nonce_directives ||= %w[script-src style-src]
    end

    def _authenticate!
      instance_eval(&RailsAdminNext::Config.authenticate_with)
    end

    def _authorize!
      instance_eval(&RailsAdminNext::Config.authorize_with)
    end

    def _audit!
      instance_eval(&RailsAdminNext::Config.audit_with)
    end

    def rails_admin_controller?
      true
    end

    rescue_from RailsAdminNext::ObjectNotFound do
      flash[:error] = I18n.t("admin.flash.object_not_found", model: @model_name, id: params[:id])
      params[:action] = "index"
      @status_code = :not_found
      index
    end

    rescue_from RailsAdminNext::ModelNotFound do
      flash[:error] = I18n.t("admin.flash.model_not_found", model: @model_name)
      params[:action] = "dashboard"
      @status_code = :not_found
      dashboard
    end
  end
end
