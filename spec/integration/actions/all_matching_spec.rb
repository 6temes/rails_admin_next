# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Bulk actions acting on every matching record", type: :request do
  let!(:smiths) { %w[Alice Bea Carol].map { FactoryBot.create :player, name: "#{it} Smithfield" } }
  let!(:outsider) { FactoryBot.create :player, name: "Dora Outsider" }
  let(:calls) { [] }

  # A host's own bulk action, added beside the built-in ones. The registry and the drawn routes
  # are restored before the next example.
  def register_host_action(all_matching:)
    calls = self.calls
    RailsAdminNext::Config::Actions.all
    RailsAdminNext::Config::Actions.collection :tag_players do
      bulkable true
      all_matching all_matching
      http_methods %i[post]
      controller do
        proc do
          calls << {bulk_ids: params[:bulk_ids], names: list_entries(@model_config, :index).map(&:name)}
          head :ok
        end
      end
    end
    Rails.application.reload_routes!
  end

  it "still treats a bulk submit with neither ids nor the flag as a cancel" do
    post(bulk_action_path(bulk_action: "export", model_name: "player"))
    expect(response).to redirect_to(index_path(model_name: "player"))
    expect(flash[:notice]).to eq "No actions were taken"
  end

  context "with a host action that has not opted in" do
    before { register_host_action(all_matching: false) }

    it "refuses a flagged bulk submit without running the action", :aggregate_failures do
      post(bulk_action_path(bulk_action: "tag_players", model_name: "player", all_matching: "true", query: "Smithfield", bulk_ids: [outsider.id]))
      expect(response).to redirect_to(index_path(model_name: "player"))
      expect(flash[:notice]).to eq "No actions were taken"
      expect(calls).to be_empty
    end

    it "gives a direct flagged submit to its own route only the submitted ids" do
      post("/admin/player/tag_players", params: {all_matching: "true", bulk_ids: [outsider.id]})
      expect(calls).to eq [{bulk_ids: [outsider.id.to_s], names: ["Dora Outsider"]}]
    end
  end

  context "with a host action that has opted in" do
    before { register_host_action(all_matching: true) }

    it "runs the action on every matching record without the ticked ids" do
      post(bulk_action_path(bulk_action: "tag_players", model_name: "player", all_matching: "true", query: "Smithfield", bulk_ids: [outsider.id]))
      expect(calls).to match [{bulk_ids: nil, names: contain_exactly("Alice Smithfield", "Bea Smithfield", "Carol Smithfield")}]
    end
  end
end
