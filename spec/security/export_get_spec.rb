# frozen_string_literal: true

require "spec_helper"

# Export must not be GET-exfiltratable. The data-streaming branch (csv/json/xml) selects the
# format off `params[:csv/json/xml]`; a bare GET could stream the whole table with
# attacker-chosen columns (via `params[:schema]`) since GET requests are CSRF-exempt. The
# streaming branch requires a non-GET, CSRF-protected request; GET only ever renders the
# export form.
RSpec.describe "Export action is not GET-exfiltratable", type: :request do
  let!(:player) { FactoryBot.create(:player, team: FactoryBot.create(:team)) }

  it "renders only the form on a GET that carries format params, and does not stream data" do
    get export_path(model_name: "player", json: true, all: true, schema: {only: ["name"]})
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Select fields to export")
    expect(response.body).not_to include(player.name)
  end

  it "streams data on a CSRF-protected POST that carries format params" do
    post export_path(model_name: "player", csv: true, all: true, schema: {only: ["name"]}, csv_options: {generator: {col_sep: ","}})
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(player.name)
  end

  context "with forgery protection enabled" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it "rejects a tokenless POST to the data branch" do
      expect do
        post export_path(model_name: "player", csv: true, all: true, schema: {only: ["name"]})
      end.to raise_error(ActionController::InvalidAuthenticityToken)
    end
  end
end
