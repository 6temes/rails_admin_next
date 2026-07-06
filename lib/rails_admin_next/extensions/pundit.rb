# frozen_string_literal: true

require "rails_admin_next/extensions/pundit/authorization_adapter"

RailsAdminNext.add_extension(:pundit, RailsAdminNext::Extensions::Pundit, authorization: true)
