# frozen_string_literal: true

require "rails_admin_next/extensions/paper_trail/auditing_adapter"

RailsAdminNext.add_extension(:paper_trail, RailsAdminNext::Extensions::PaperTrail, auditing: true)
