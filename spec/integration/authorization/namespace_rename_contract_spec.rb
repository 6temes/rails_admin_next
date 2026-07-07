# frozen_string_literal: true

require "spec_helper"

# Characterization spec for the RailsAdmin -> RailsAdminNext namespace rename.
#
# It freezes the authorization contract that MUST survive the rename, because a
# renamed authorization subject can fail *open* (a `cannot` that no longer matches
# silently grants access). Three things are frozen here:
#
#   1. the host-facing access subject `:access, :rails_admin` (never `:rails_admin_next`);
#   2. every action's `authorization_key` (action key => authorization symbol);
#   3. an end-to-end CanCanCan ability granting `:access, :rails_admin` authorizes
#      the dashboard.
#
# The snake-case `:rails_admin` symbols below are the frozen contract and intentionally
# do NOT become `:rails_admin_next` when the module is renamed.

# Single source of truth: action key => authorization_key. A drift here means a host's
# CanCanCan/Pundit rule could silently stop matching after an internal action tidy.
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

  describe "CanCanCan access gate" do
    let(:user) { FactoryBot.create(:user, roles: [:admin]) }

    before do
      # A host-supplied ability. The access subject is `:rails_admin` and stays that way.
      stub_const("FrozenContractAbility", Class.new do
        include CanCan::Ability

        def initialize(user)
          return unless user.roles.include?(:admin)

          can :access, :rails_admin
          can :manage, :all
        end
      end)

      RailsAdminNext.config do |c|
        c.authorize_with :cancancan, FrozenContractAbility
        c.authenticate_with { warden.authenticate! scope: :user }
        c.current_user_method(&:current_user)
      end
      login_as user
    end

    it "authorizes dashboard access for an ability granting :access, :rails_admin" do
      visit dashboard_path
      expect(page).to have_content "Site Administration"
    end

    it "denies access when :access, :rails_admin is not granted" do
      user.update(roles: [])
      expect { visit dashboard_path }.to raise_error(CanCan::AccessDenied)
    end
  end
end
