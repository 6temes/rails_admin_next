# frozen_string_literal: true

require "spec_helper"

RSpec.describe "BulkDelete action", type: :request do
  subject { page }

  describe "confirmation page" do
    before do
      @players = FactoryBot.create_list(:player, 2)
    end

    it "shows names of to-be-deleted players" do
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: @players.collect(&:id)))
      @players.each { |player| expect(response.body).to include(player.name) }
    end

    it "redirects to list when all of the records is already deleted" do
      expect(Player.count).to eq @players.length
      player_ids = [@players.first.id]
      @players.first.destroy # delete selected object before send request to show bulk_delete confirmation.

      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: player_ids))
      expect(response.response_code).to eq 302

      index_url = response.headers["Location"]
      expect(URI.parse(index_url).path).to eq(index_path(model_name: "player"))
      visit index_url

      is_expected.to have_no_content(@players.first.name)
      is_expected.to have_content(@players.last.name)
    end

    it "returns error message for DELETE request if the records are already deleted" do
      expect(Player.count).to eq @players.length
      player_ids = [@players.first.id]
      @players.first.destroy # delete selected object before send request to delete it.

      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: player_ids))
      expect(response.response_code).to eq 302
      expect(flash[:error]).to match(/0 players failed to be deleted/i)
    end

    it "returns error message for DELETE request without bulk_ids" do
      expect(Player.count).to eq @players.length
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: ""))
      expect(response.response_code).to eq 302
      expect(flash[:error]).to match(/0 players failed to be deleted/i)
    end
  end

  describe "flash wording" do
    let(:players) { FactoryBot.create_list(:player, 2) }

    before do
      RailsAdminNext.config Player do
        label "Squad member"
        label_plural "Squad"
      end
    end

    it "uses the configured plural label for several records" do
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: players.map(&:id)))
      expect(flash[:success]).to eq("2 Squad successfully deleted")
    end

    it "uses the configured plural label for zero records" do
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: ""))
      expect(flash[:error]).to eq("0 Squad failed to be deleted")
    end

    it "keeps the singular label for one record" do
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: [players.first.id]))
      expect(flash[:success]).to eq("1 Squad member successfully deleted")
    end

    it "follows a translated plural" do
      I18n.backend.store_translations(:en, activerecord: {models: {team: {one: "Squad member", other: "Squad"}}})
      teams = FactoryBot.create_list(:team, 2)
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "team", bulk_ids: teams.map(&:id)))
      expect(flash[:success]).to eq("2 Squad successfully deleted")
    ensure
      I18n.reload!
    end
  end

  describe "with a scope tab selected" do
    let!(:red_team) { FactoryBot.create(:team, name: "Red Sox", color: "red") }
    let!(:white_team) { FactoryBot.create(:team, name: "White Sox", color: "white") }

    before do
      RailsAdminNext.config Team do
        list do
          scopes [nil, :red, :white]
        end
      end
    end

    it "lists only the records in that tab on the confirmation page" do
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "team", scope: "red", bulk_ids: [red_team.id, white_team.id]))
      expect(response.body).to include("Red Sox")
      expect(response.body).not_to include("White Sox")
    end

    it "carries the tab into the confirmation form" do
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "team", scope: "red", bulk_ids: [red_team.id, white_team.id]))
      form_action = Nokogiri::HTML(response.body).at_css("form[action*='bulk_delete']")["action"]
      expect(Rack::Utils.parse_nested_query(URI.parse(form_action).query)).to include("scope" => "red")
    end

    it "destroys only the records in that tab, whatever ids are submitted" do
      delete(bulk_delete_path(model_name: "team", scope: "red", bulk_ids: [red_team.id, white_team.id]))
      expect(flash[:success]).to match(/1 Team successfully deleted/i)
      expect(Team.where(id: red_team.id)).not_to exist
      expect(Team.where(id: white_team.id)).to exist
    end
  end

  context "on destroy" do
    before do
      @players = Array.new(3) { FactoryBot.create(:player) }
      @delete_ids = @players[0..1].collect(&:id)

      # NOTE: This uses an internal, unsupported capybara API which could break at any moment. We
      # should refactor this test so that it either A) uses capybara's supported API (only GET
      # requests via visit) or B) just uses Rack::Test (and doesn't use capybara for browser
      # interaction like click_button).
      page.driver.browser.reset_host!
      page.driver.browser.process :post, bulk_action_path(:bulk_action => "bulk_delete", :model_name => "player", :bulk_ids => @delete_ids, "_method" => "post")
      click_button "Yes, I'm sure"
    end

    it "does not contain deleted records" do
      expect(RailsAdminNext::AbstractModel.new("Player").all.pluck(:id)).to eq([@players[2].id])
      expect(page).to have_selector(".alert-success", text: "2 Players successfully deleted")
    end
  end

  context "on cancel" do
    before do
      @players = Array.new(3) { FactoryBot.create(:player) }
      @delete_ids = @players[0..1].collect(&:id)

      visit index_path(model_name: "player")
      @delete_ids.each { |id| find(%(input[name="bulk_ids[]"][value="#{id}"])).click }
      click_button "Selected items"
      click_link "Delete selected Players"
    end

    it "does not delete records", js: true do
      find_button("Cancel").trigger("click")
      is_expected.to have_text "No actions were taken"
      expect(RailsAdminNext::AbstractModel.new("Player").count).to eq(3)
    end
  end

  context "with a record restricted by dependent: :restrict_with_exception", active_record: true do
    # Created before the deletable one so it sorts first under the default primary-key
    # order: the batch has to survive the raise and still reach the records behind it.
    let!(:restricted) { FactoryBot.create(:player, team: FactoryBot.create(:exception_restricted_team)).team }
    let!(:deletable) { FactoryBot.create :exception_restricted_team }

    it "deletes the unrestricted records and reports the restricted ones" do
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "exception_restricted_team", bulk_ids: [restricted.id, deletable.id]))

      expect(response.response_code).to eq 302
      expect(flash[:success]).to match(/1 Exception restricted team successfully deleted/i)
      expect(flash[:error]).to match(/1 Exception restricted team failed to be deleted/i)
      expect(Team.where(id: deletable.id)).not_to exist
      expect(Team.where(id: restricted.id)).to exist
    end

    it "reports every record when all of them are restricted" do
      also_restricted = FactoryBot.create(:player, team: FactoryBot.create(:exception_restricted_team)).team

      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "exception_restricted_team", bulk_ids: [restricted.id, also_restricted.id]))

      expect(flash[:success]).to be_nil
      expect(flash[:error]).to match(/2 Exception restricted teams failed to be deleted/i)
      expect(Team.where(id: [restricted.id, also_restricted.id]).count).to eq 2
    end

    it "records nothing for the restricted record" do
      RailsAdminNext.config do |config|
        config.audit_with :paper_trail
      end
      expect_any_instance_of(RailsAdminNext::Extensions::PaperTrail::AuditingAdapter).to receive(:delete_object).once

      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "exception_restricted_team", bulk_ids: [deletable.id, restricted.id]))
    end
  end

  context "with composite primary keys", composite_primary_keys: true do
    let!(:fanships) { FactoryBot.create_list(:fanship, 3) }

    it "provides check boxes for bulk operation" do
      visit index_path(model_name: "fanship")
      fanships.each { |fanship| is_expected.to have_css(%(input[name="bulk_ids[]"][value="#{fanship.id}"])) }
    end

    it "deletes selected records" do
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "fanship", bulk_ids: fanships[0..1].map { |fanship| RailsAdminNext::Support::CompositeKeysSerializer.serialize(fanship.id) }))
      expect(flash[:success]).to match(/2 Fanships successfully deleted/)
      expect(Fanship.all).to eq fanships[2..2]
    end
  end
end
