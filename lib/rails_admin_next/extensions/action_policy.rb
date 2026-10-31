# frozen_string_literal: true

require "rails_admin_next/extensions/action_policy/authorization_adapter"

RailsAdminNext.add_extension(:action_policy, RailsAdminNext::Extensions::ActionPolicy, authorization: true)
