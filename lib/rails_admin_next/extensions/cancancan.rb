# frozen_string_literal: true

require "rails_admin_next/extensions/cancancan/authorization_adapter"

RailsAdminNext.add_extension(:cancancan, RailsAdminNext::Extensions::CanCanCan, authorization: true)
