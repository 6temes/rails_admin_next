# frozen_string_literal: true

Rails.application.config.middleware.use Warden::Manager do |manager|
  manager.default_scope = :user
  manager.default_strategies :password
  manager.failure_app = ->(_env) { [401, {"Content-Type" => "text/plain"}, ["Unauthorized"]] }
  manager.serialize_into_session(&:id)
  manager.serialize_from_session { |id| User.find_by(id: id) }
end

Warden::Strategies.add(:password) do
  def valid?
    params["user"] && params["user"]["email"]
  end

  def authenticate!
    user = User.find_by(email: params["user"]["email"])
    user ? success!(user) : fail!("Invalid email or password")
  end
end

# A real Warden-based host (Devise, Rodauth, authentication-zero, …) exposes `warden` and
# `current_user` to every controller via its own gem — including the mounted RailsAdminNext engine
# controller, which inherits from ::ActionController::Base. The engine itself stays auth-agnostic and
# never references Warden directly; this dummy host has no such gem, so it hand-rolls the equivalent
# helpers here.
module WardenControllerHelpers
  def warden
    request.env["warden"] ||= _build_warden_test_proxy
  end

  def current_user
    warden&.user(:user)
  end

  private

  # Request/integration specs go through the real Warden::Manager middleware, so the `||=`
  # above is a no-op for them. Controller specs bypass the Rack stack (request.env['warden']
  # is nil), so build a proxy lazily here — firing login_as's on_request hooks on first access.
  def _build_warden_test_proxy
    manager = Warden::Manager.new(nil) do |m|
      m.default_scope = :user
      m.failure_app = ->(_env) { [401, {"Content-Type" => "text/plain"}, ["Unauthorized"]] }
      m.serialize_into_session(&:id)
      m.serialize_from_session { |id| User.find_by(id: id) }
    end
    proxy = Warden::Proxy.new(request.env, manager)
    proxy.on_request
    proxy
  end
end

ActiveSupport.on_load(:action_controller) do
  include WardenControllerHelpers
end
