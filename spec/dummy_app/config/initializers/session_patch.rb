# frozen_string_literal: true

require "action_dispatch/middleware/session/abstract_store"

# A stale session cookie referencing a class that no longer matches the app's current session
# serialization (e.g. after changing which model or gem handles authentication) makes ActionDispatch
# raise ActionDispatch::Session::SessionRestoreError, which prevents the app from booting until the
# browser's cookie is manually cleared. Rescue here instead, so a stale cookie is just treated as no
# session and the user logs in again.

ActionDispatch::Session::StaleSessionCheck.module_eval do
  def stale_session_check!
    yield
  rescue ArgumentError
    {}
  end
end
