# The including spec stubs a Player policy whose scope resolves to nil, and signs in a user
# who may list players.
RSpec.shared_examples "an authorization scope that resolves to nil" do
  let!(:player) { FactoryBot.create(:player, name: "Hidden player") }

  it "lists nothing" do
    visit index_path(model_name: "player")

    is_expected.not_to have_content("Hidden player")
  end

  it "lists nothing under a list scope tab" do
    RailsAdminNext.config(Player) { list { scopes [nil, :unscoped] } }

    visit index_path(model_name: "player", scope: "unscoped")

    is_expected.not_to have_content("Hidden player")
  end

  it "exports nothing" do
    page.driver.post(export_path(model_name: "player", schema: {only: ["name"]}, csv: true, all: true, csv_options: {generator: {col_sep: ","}}))

    expect(page.driver.response.body).not_to include("Hidden player")
  end

  it "counts nothing on the dashboard" do
    visit dashboard_path

    expect(find("tr.player_links .progress-bar")).to have_text(/\A\s*0\s*\z/)
  end

  it "offers nothing in an association picker" do
    team = FactoryBot.create(:team)

    visit index_path(model_name: "player", associated_collection: "players", current_action: "update",
      source_abstract_model: "team", source_object_id: team.id, format: :json)

    expect(JSON.parse(page.body)).to eq []
  end
end
