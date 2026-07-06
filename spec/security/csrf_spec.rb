# frozen_string_literal: true

require "spec_helper"

# CSRF protection is hardcoded to `protect_from_forgery with: :exception`, with no
# host-configurable option to weaken it (e.g. to `:null_session`). A forged (tokenless)
# non-GET request must be rejected with an `ActionController::InvalidAuthenticityToken` —
# which renders as HTTP 422 in any app that leaves `action_dispatch.show_exceptions` on (the
# test env turns it off, so it surfaces here as the raised exception). GET stays exempt so the
# confirmation pages still render.
RSpec.describe "CSRF protection", type: :request do
  let!(:player) { FactoryBot.create :player, team: FactoryBot.create(:team) }

  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  it "hardcodes the exception strategy and removes the host-configurable option" do
    expect(RailsAdminNext::ApplicationController.forgery_protection_strategy).to eq(ActionController::RequestForgeryProtection::ProtectionMethods::Exception)
    expect(RailsAdminNext.config).not_to respond_to(:forgery_protection_settings)
    expect(RailsAdminNext::Config).not_to respond_to(:forgery_protection_settings)
  end

  it "rejects a tokenless DELETE and leaves the record intact" do
    expect { delete delete_path(model_name: "player", id: player.id) }.to raise_error(ActionController::InvalidAuthenticityToken)
    expect(Player.exists?(player.id)).to be(true)
  end

  it "rejects a tokenless DELETE that accepts turbo_stream (no format side-door)" do
    expect do
      delete delete_path(model_name: "player", id: player.id),
        headers: {"Accept" => "text/vnd.turbo-stream.html"}
    end.to raise_error(ActionController::InvalidAuthenticityToken)
    expect(Player.exists?(player.id)).to be(true)
  end

  it "lets the same DELETE through once forgery protection is satisfied" do
    ActionController::Base.allow_forgery_protection = false
    delete delete_path(model_name: "player", id: player.id)
    expect(Player.exists?(player.id)).to be(false)
  end
end
