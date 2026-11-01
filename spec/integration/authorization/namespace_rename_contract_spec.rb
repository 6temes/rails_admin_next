# frozen_string_literal: true

require "spec_helper"

# Characterization spec for the RailsAdmin -> RailsAdminNext namespace rename.
#
# It freezes every action's `authorization_key` (action key => authorization symbol).
# A host's policy or custom adapter matches on these names, so a drift after an internal
# action tidy silently stops a host rule from matching, and a deny rule that no longer
# matches fails open.
FROZEN_AUTHORIZATION_KEYS = {
  bulk_delete: :destroy,
  dashboard: :dashboard,
  delete: :destroy,
  edit: :edit,
  export: :export,
  history_index: :history,
  history_show: :history,
  index: :index,
  new: :new,
  show: :show,
  show_in_app: :show_in_app
}.freeze

RSpec.describe "Authorization contract (frozen across the namespace rename)", type: :request do
  describe "action authorization_key table" do
    let(:actual_keys) do
      RailsAdminNext::Config::Actions.all.to_h { |action| [action.key, action.authorization_key] }
    end

    it "maps every registered action to its frozen authorization_key", :aggregate_failures do
      FROZEN_AUTHORIZATION_KEYS.each do |action_key, authorization_key|
        expect(actual_keys[action_key]).to eq(authorization_key),
          "#{action_key}.authorization_key drifted: " \
          "#{actual_keys[action_key].inspect} != #{authorization_key.inspect}"
      end
    end
  end
end
