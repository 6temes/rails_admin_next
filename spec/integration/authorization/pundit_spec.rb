# frozen_string_literal: true

require "spec_helper"
require "csv"

RSpec.describe "RailsAdminNext Pundit Authorization", type: :request do
  subject { page }

  before do
    RailsAdminNext.config do |c|
      c.authorize_with(:pundit)
      c.authenticate_with { warden.authenticate! scope: :user }
      c.current_user_method(&:current_user)
    end
    @player_model = RailsAdminNext::AbstractModel.new(Player)
    @user = FactoryBot.create :user, roles: []
    login_as @user
  end

  describe "with no roles" do
    it "GET /admin should raise Pundit::NotAuthorizedError" do
      expect { visit dashboard_path }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "GET /admin/player should raise Pundit::NotAuthorizedError" do
      expect { visit index_path(model_name: "player") }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "with read player role" do
    before do
      @user.update(roles: %i[admin read_player])
    end

    it "GET /admin should show Player but not League" do
      visit dashboard_path
      is_expected.to have_content("Player")
      is_expected.not_to have_content("League")
      is_expected.not_to have_content("Add new")
    end

    it "GET /admin/team should raise Pundit::NotAuthorizedError" do
      expect { visit index_path(model_name: "team") }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "GET /admin/player/1/edit should raise access denied" do
      @player = FactoryBot.create :player
      expect { visit edit_path(model_name: "player", id: @player.id) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "GET /admin/player/new should raise Pundit::NotAuthorizedError" do
      expect { visit new_path(model_name: "player") }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "GET /admin/player lists only the policy Scope's players and shows only permitted member links", :aggregate_failures do
      RailsAdminNext.config Player do
        list do
          field :name
        end
      end
      active_player = FactoryBot.create(:player, retired: false)
      retired_player = FactoryBot.create(:player, retired: true)

      visit index_path(model_name: "player")

      is_expected.to have_content(active_player.name)
      is_expected.not_to have_content(retired_player.name)
      is_expected.not_to have_content("Add new")
      is_expected.to have_css(".show_member_link")
      is_expected.not_to have_css(".edit_member_link")
      is_expected.not_to have_css(".delete_member_link")
      is_expected.not_to have_css(".history_show_member_link")
      is_expected.not_to have_css(".show_in_app_member_link")
    end

    context "with a scope tab on a composite primary key model", composite_primary_keys: true do
      let!(:readable) { FactoryBot.create(:fanship, since: nil) }
      let!(:unreadable) { FactoryBot.create(:fanship, since: Date.new(2020, 1, 1)) }

      before do
        @user.update(roles: %i[admin read_fanship])
        RailsAdminNext.config Fanship do
          list { scopes [nil, :unscoped] }
        end
      end

      it "does not let a tab that drops conditions list unauthorized records" do
        visit index_path(model_name: "fanship", scope: "unscoped")
        is_expected.to have_content(readable.fan.name)
        is_expected.not_to have_content(unreadable.fan.name)
      end
    end

    context "with scope tabs" do
      before do
        FactoryBot.create(:player, name: "Active Player", retired: false)
        FactoryBot.create(:player, name: "Retired Player", retired: true)
        RailsAdminNext.config Player do
          list do
            scopes [nil, :unscoped, :retired]
            field :name
          end
        end
      end

      it "does not let a tab that drops conditions list unauthorized records" do
        visit index_path(model_name: "player", scope: "unscoped")
        is_expected.to have_content("Active Player")
        is_expected.not_to have_content("Retired Player")
      end

      it "keeps a tab's condition on a column the policy Scope also constrains" do
        visit index_path(model_name: "player", scope: "retired")
        is_expected.not_to have_content("Active Player")
        is_expected.not_to have_content("Retired Player")
      end
    end
  end

  describe "with export player role" do
    before do
      @user.update(roles: %i[admin export_player])
      RailsAdminNext.config(Player) do
        export do
          field :name
        end
      end
      stub_const("RailsAdminNext::CSVConverter::BATCH_SIZE", 1)
      %w[Charlie Alice].each { FactoryBot.create :player, name: it }
      FactoryBot.create :player, name: "Bob", retired: true
    end

    it "POST /admin/player/export exports only permitted players, in the requested sort" do
      page.driver.post(export_path(model_name: "player", schema: {only: ["name"]}, csv: true, all: true, sort: "name", csv_options: {generator: {col_sep: ","}}))
      csv = CSV.parse(page.driver.response.body)

      expect(csv).to eq [["Name"], ["Alice"], ["Charlie"]]
    end

    context "with associations in the schema" do
      before do
        stub_const("TeamPolicy", Class.new(ApplicationPolicy) { def index? = true })
        stub_const("TeamPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = scope.where.not(name: "Yankees") })
        stub_const("DraftPolicy", Class.new(ApplicationPolicy))
        stub_const("DraftPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = scope.all })
        RailsAdminNext.config(Player) do
          export do
            field :name
            field :team
            field :draft
          end
        end
        RailsAdminNext.config(Team) { export { field :name } }
        RailsAdminNext.config(Draft) { export { field :college } }
        Player.find_by!(name: "Alice").update!(team: FactoryBot.create(:team, name: "Mets"))
        FactoryBot.create :draft, player: Player.find_by!(name: "Alice"), college: "Yale"
      end

      let(:schema) { {only: ["name"], include: {team: {only: ["name"]}, draft: {only: ["college"]}}} }

      it "exports only the associations whose model the user may list", :aggregate_failures do
        page.driver.post(export_path(model_name: "player", schema:, csv: true, all: true, sort: "name", csv_options: {generator: {col_sep: ","}}))
        expect(CSV.parse(page.driver.response.body)).to eq [["Name", "Name [Team]"], ["Alice", "Mets"], ["Charlie", ""]]

        page.driver.post(export_path(model_name: "player", schema:, json: true, all: true, sort: "name"))
        expect(JSON.parse(page.driver.response.body).first).to eq("name" => "Alice", "team" => {"name" => "Mets"})

        page.driver.post(export_path(model_name: "player", schema:, xml: true, all: true, sort: "name"))
        expect(page.driver.response.body).to include("<name>Mets</name>")
        expect(page.driver.response.body).not_to include("Yale")
      end

      it "leaves out an association whose model has the index action disabled" do
        RailsAdminNext.config do |c|
          c.actions do
            dashboard
            index { except %w[Team] }
            export
          end
        end
        page.driver.post(export_path(model_name: "player", schema:, json: true, all: true, sort: "name"))
        expect(JSON.parse(page.driver.response.body).first).to eq("name" => "Alice")
      end

      it "asks the rule named by the index action's authorization_key" do
        RailsAdminNext.config do |c|
          c.actions do
            dashboard
            index { authorization_key :rails_admin_index }
            export
          end
        end
        page.driver.post(export_path(model_name: "player", schema:, json: true, all: true, sort: "name"))
        expect(JSON.parse(page.driver.response.body).first).to eq("name" => "Alice", "team" => {"name" => "Mets"}, "draft" => {"college" => "Yale"})
      end

      context "when the associated model's scope hides some of its records" do
        before do
          Player.find_by!(name: "Charlie").update!(team: FactoryBot.create(:team, name: "Yankees"))
        end

        it "exports only the associated records the scope lets the user list", :aggregate_failures do
          page.driver.post(export_path(model_name: "player", schema:, csv: true, all: true, sort: "name", csv_options: {generator: {col_sep: ","}}))
          expect(CSV.parse(page.driver.response.body)).to eq [["Name", "Name [Team]"], ["Alice", "Mets"], ["Charlie", ""]]

          page.driver.post(export_path(model_name: "player", schema:, json: true, all: true, sort: "name"))
          expect(JSON.parse(page.driver.response.body)).to eq [{"name" => "Alice", "team" => {"name" => "Mets"}}, {"name" => "Charlie"}]

          page.driver.post(export_path(model_name: "player", schema:, xml: true, all: true, sort: "name"))
          expect(page.driver.response.body).to include("<name>Mets</name>")
          expect(page.driver.response.body).not_to include("Yankees")
        end

        it "exports only the records of a has-many association the scope lets the user list" do
          @user.update(roles: %i[admin export_player])
          Player.find_by!(name: "Bob").update!(team: Team.find_by!(name: "Mets"))
          RailsAdminNext.config(Team) do
            export do
              field :name
              field :players
            end
          end
          RailsAdminNext.config(Player) { export { field :name } }
          team_schema = {only: ["name"], include: {players: {only: ["name"]}}}

          page.driver.post(export_path(model_name: "team", schema: team_schema, json: true, all: true, sort: "name"))
          expect(JSON.parse(page.driver.response.body).find { it["name"] == "Mets" }).to eq("name" => "Mets", "players" => [{"name" => "Alice"}])
        end
      end

      context "with through associations" do
        let(:league) { FactoryBot.create(:league, name: "Majors") }
        let(:league_schema) { {only: ["name"], include: {teams: {only: ["name"]}, players: {only: ["name"]}}} }

        before do
          stub_const("LeaguePolicy", Class.new(ApplicationPolicy) { def index? = true })
          stub_const("LeaguePolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = scope.all })
          division = FactoryBot.create(:division, custom_league_id: league.id)
          Team.find_by!(name: "Mets").update!(division:)
          yankees = FactoryBot.create(:team, name: "Yankees", division:)
          Player.find_by!(name: "Charlie").update!(team: yankees)
          Player.find_by!(name: "Bob").update!(team: Team.find_by!(name: "Mets"))
          RailsAdminNext.config(League) do
            export do
              field :name
              field :teams
              field :players
            end
          end
          RailsAdminNext.config(Team) { export { field :name } }
          RailsAdminNext.config(Player) { export { field :name } }
        end

        # In the request body, as a query string would sort players ahead of teams.
        it "keeps the listable records reached through a hidden one when the through association comes first", :aggregate_failures do
          page.driver.post(export_path(model_name: "league", json: true, all: true), schema: league_schema)
          league_json = JSON.parse(page.driver.response.body).sole
          expect(league_json["teams"]).to eq [{"name" => "Mets"}]
          expect(league_json["players"]).to contain_exactly({"name" => "Alice"}, {"name" => "Charlie"})

          page.driver.post(export_path(model_name: "league", csv: true, all: true, csv_options: {generator: {col_sep: ","}}), schema: league_schema)
          header, row = CSV.parse(page.driver.response.body)
          expect(header).to eq ["Name", "Name [Teams]", "Name [Players]"]
          expect(row[0..1]).to eq ["Majors", "Mets"]
          expect(row[2].split(",")).to contain_exactly("Alice", "Charlie")

          page.driver.post(export_path(model_name: "league", xml: true, all: true), schema: league_schema)
          expect(page.driver.response.body).to include("<name>Charlie</name>")
          expect(page.driver.response.body).not_to include("Yankees", "Bob")
        end

        context "when the through association has a where scope" do
          around do |example|
            League.has_many :named_players, -> { where.not(name: nil) }, through: :teams, source: :players
            example.run
          ensure
            League._reflections = League._reflections.except(:named_players)
            League.clear_reflections_cache
          end

          it "exports only the records the associated model's scope lets the user list" do
            RailsAdminNext.config(League) do
              export do
                field :name
                field :named_players
              end
            end
            schema = {only: ["name"], include: {named_players: {only: ["name"]}}}

            page.driver.post(export_path(model_name: "league", schema:, json: true, all: true))
            expect(JSON.parse(page.driver.response.body).sole["named_players"]).to contain_exactly({"name" => "Alice"}, {"name" => "Charlie"})
          end
        end
      end

      it "exports no associated record when the associated model's scope resolves to nil" do
        stub_const("TeamPolicy::Scope", Class.new(ApplicationPolicy::Scope) { def resolve = nil })
        page.driver.post(export_path(model_name: "player", schema:, json: true, all: true, sort: "name"))
        expect(JSON.parse(page.driver.response.body)).to eq [{"name" => "Alice"}, {"name" => "Charlie"}]
      end

      it "loads each included association in one query per batch, however many rows" do
        stub_const("RailsAdminNext::CSVConverter::BATCH_SIZE", 100)
        export = ->(format) do
          queries = 0
          counter = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:sql].start_with?("SAVEPOINT", "RELEASE") }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
            page.driver.post(export_path({model_name: "player", schema:, all: true, sort: "name", csv_options: {generator: {col_sep: ","}}}.merge(format => true)))
          end
          queries
        end

        export.call(:csv) # the first request skips the signed-in user's lookup
        before = %i[csv json xml].index_with(&export)
        3.times { FactoryBot.create(:draft, player: FactoryBot.create(:player, team: FactoryBot.create(:team))) }
        expect(%i[csv json xml].index_with(&export)).to eq before
      end

      it "includes an association whose index rule returns a truthy non-boolean" do
        stub_const("TeamPolicy", Class.new(TeamPolicy) { def index? = [] })
        page.driver.post(export_path(model_name: "player", schema:, json: true, all: true, sort: "name"))
        expect(JSON.parse(page.driver.response.body).first).to eq("name" => "Alice", "team" => {"name" => "Mets"})
      end

      it "offers on the export form only the associations whose model the user may list", :aggregate_failures do
        visit export_path(model_name: "player")
        is_expected.to have_field("schema_include_team_only_name")
        is_expected.not_to have_field("schema_include_draft_only_college")
      end
    end
  end

  describe "with admin role" do
    before do
      @user.update(roles: %i[admin manage_player])
    end

    it "GET /admin should show Player but not League" do
      visit dashboard_path
      is_expected.to have_content("Player")
    end

    it "GET /admin/player/new should render and create record upon submission" do
      visit new_path(model_name: "player")

      is_expected.to have_content("Save and edit")
      is_expected.not_to have_content("Delete")

      is_expected.to have_content("Save and add another")
      fill_in "player[name]", with: "Jackie Robinson"
      fill_in "player[number]", with: "42"
      fill_in "player[position]", with: "Second baseman"
      click_button "Save"
      is_expected.not_to have_content("Edit")

      @player = RailsAdminNext::AbstractModel.new("Player").first
      expect(@player.name).to eq("Jackie Robinson")
      expect(@player.number).to eq(42)
      expect(@player.position).to eq("Second baseman")
    end
  end

  describe "with all roles" do
    it "shows links to all actions" do
      @user.update(roles: %i[admin manage_player])
      @player = FactoryBot.create :player

      visit index_path(model_name: "player")
      is_expected.to have_css(".show_member_link")
      is_expected.to have_css(".edit_member_link")
      is_expected.to have_css(".delete_member_link")
      is_expected.to have_css(".history_show_member_link")
      is_expected.to have_css(".show_in_app_member_link")

      visit show_path(model_name: "player", id: @player.id)
      is_expected.to have_content("Show")
      is_expected.to have_content("Edit")
      is_expected.to have_content("Delete")
      is_expected.to have_content("History")
      is_expected.to have_content("Show in app")
    end
  end

  describe "with create and read player role" do
    before do
      @user.update(roles: %i[admin read_player create_player])
    end

    it "GET /admin/player/new pre-fills the policy's attributes_for and creates a suspended record", :aggregate_failures do
      visit new_path(model_name: "player")
      is_expected.not_to have_content("Save and edit")

      fill_in "player[name]", with: "Jackie Robinson"
      fill_in "player[number]", with: "42"
      fill_in "player[position]", with: "Second baseman"
      click_button "Save"

      player = Player.find_by!(name: "Jackie Robinson")
      expect(player).to be_suspended
    end

    it "POST /admin/player/new with unauthorized attribute value should raise access denied" do
      visit new_path(model_name: "player")
      fill_in "player[name]", with: "Jackie Robinson"
      choose name: "player[suspended]", option: "0"
      expect { click_button "Save" }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "with update and read player role" do
    before do
      @user.update(roles: %i[admin read_player update_player])
    end

    it "GET /admin/player/1/edit should render and update record upon submission" do
      @player = FactoryBot.create :player
      visit edit_path(model_name: "player", id: @player.id)
      fill_in "player[name]", with: "Jackie Robinson"
      click_button "Save"
      expect(@player.reload.name).to eq("Jackie Robinson")
    end

    it "GET /admin/player/1/edit with retired player should raise access denied" do
      @player = FactoryBot.create :player, retired: true
      expect { visit edit_path(model_name: "player", id: @player.id) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "PUT /admin/player/new with unauthorized attribute value should raise access denied" do
      @player = FactoryBot.create :player
      visit edit_path(model_name: "player", id: @player.id)
      choose name: "player[retired]", option: "1"
      expect { click_button "Save" }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "GET /admin/player/1/delete should raise access denied" do
      @player = FactoryBot.create :player
      expect { visit delete_path(model_name: "player", id: @player.id) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "with destroy and read player role" do
    let!(:active_player) { FactoryBot.create :player, retired: false }
    let!(:retired_player) { FactoryBot.create :player, retired: true }

    before do
      @user.update(roles: %i[admin read_player destroy_player])
    end

    it "GET /admin/player/1/delete should render and destroy record upon submission" do
      visit delete_path(model_name: "player", id: active_player.id)
      click_button "Yes, I'm sure"
      expect(@player_model.get(active_player.id)).to be_nil
    end

    it "GET /admin/player/1/delete with retired player should raise access denied" do
      expect { visit delete_path(model_name: "player", id: retired_player.id) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "POST /admin/player/bulk_delete should render only records the policy Scope returns" do
      post bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: [active_player, retired_player].collect(&:id))

      expect(response.body).to include(active_player.name)
      expect(response.body).not_to include(retired_player.name)
    end

    it "DELETE /admin/player/bulk_delete should destroy only records the policy Scope returns" do
      delete bulk_delete_path(model_name: "player", bulk_ids: [active_player, retired_player].collect(&:id))
      expect(@player_model.get(active_player.id)).to be_nil
      expect(@player_model.get(retired_player.id)).not_to be_nil
    end

    context "with a destroy? rule that depends on the record" do
      let!(:suspended_player) { FactoryBot.create :player, suspended: true }

      before { allow(Player).to receive(:policy_class).and_return(SuspendedPlayerPolicy) }

      it "GET /admin/player/1/delete with a suspended player should raise access denied" do
        expect { visit delete_path(model_name: "player", id: suspended_player.id) }.to raise_error(Pundit::NotAuthorizedError)
      end

      it "POST /admin/player/bulk_delete does not list records destroy? refuses", :aggregate_failures do
        post bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: [active_player, suspended_player].collect(&:id))

        expect(response.body).to include(active_player.name)
        expect(response.body).not_to include(suspended_player.name)
      end

      it "DELETE /admin/player/bulk_delete leaves records destroy? refuses and counts them as failed", :aggregate_failures do
        delete bulk_delete_path(model_name: "player", bulk_ids: [active_player, suspended_player].collect(&:id))

        expect(@player_model.get(active_player.id)).to be_nil
        expect(@player_model.get(suspended_player.id)).not_to be_nil
        expect(flash[:success]).to eq "1 Player successfully deleted"
        expect(flash[:error]).to eq "1 Player failed to be deleted"
      end
    end

    it "DELETE /admin/player/bulk_delete asks each record the bulk action's own authorization_key", :aggregate_failures do
      suspended_player = FactoryBot.create :player, suspended: true
      allow(Player).to receive(:policy_class).and_return(GuardedDestroyPlayerPolicy)
      RailsAdminNext.config do |c|
        c.actions do
          dashboard
          index
          bulk_delete do
            authorization_key :guarded_destroy
          end
        end
      end

      delete bulk_delete_path(model_name: "player", bulk_ids: [active_player, suspended_player].collect(&:id))

      expect(@player_model.get(active_player.id)).to be_nil
      expect(@player_model.get(suspended_player.id)).not_to be_nil
    end

    it "does not let a tab that drops conditions destroy unauthorized records" do
      RailsAdminNext.config Player do
        list do
          scopes [nil, :unscoped]
        end
      end

      delete bulk_delete_path(model_name: "player", scope: "unscoped", bulk_ids: [active_player, retired_player].collect(&:id))
      expect(@player_model.get(active_player.id)).to be_nil
      expect(@player_model.get(retired_player.id)).not_to be_nil
    end
  end

  describe "with history role" do
    it "shows links to history action", :aggregate_failures do
      @user.update(roles: %i[admin read_player history_player])
      @player = FactoryBot.create :player

      visit index_path(model_name: "player")
      is_expected.to have_css(".show_member_link")
      is_expected.not_to have_css(".edit_member_link")
      is_expected.not_to have_css(".delete_member_link")
      is_expected.to have_css(".history_show_member_link")

      visit show_path(model_name: "player", id: @player.id)
      is_expected.to have_content("Show")
      is_expected.not_to have_content("Edit")
      is_expected.not_to have_content("Delete")
      is_expected.to have_content("History")
    end
  end

  describe "history of records outside the policy Scope", active_record: true do
    before { @user.update(roles: %i[admin]) }

    it_behaves_like "history within the authorization scope", ScopedPaperTrailTestPolicy
  end

  describe "with show in app role" do
    it "shows links to show in app action", :aggregate_failures do
      @user.update(roles: %i[admin read_player show_in_app_player])
      @player = FactoryBot.create :player

      visit index_path(model_name: "player")
      is_expected.to have_css(".show_member_link")
      is_expected.not_to have_css(".edit_member_link")
      is_expected.not_to have_css(".delete_member_link")
      is_expected.not_to have_css(".history_show_member_link")
      is_expected.to have_css(".show_in_app_member_link")

      visit show_path(model_name: "player", id: @player.id)
      is_expected.to have_content("Show")
      is_expected.not_to have_content("Edit")
      is_expected.not_to have_content("Delete")
      is_expected.not_to have_content("History")
      is_expected.to have_content("Show in app")
    end
  end

  describe "association picker source record" do
    let!(:team) { FactoryBot.create(:team) }
    let!(:teammate) { FactoryBot.create(:player, team:) }
    let!(:free_agent) { FactoryBot.create(:player) }

    before do
      stub_const("TeamPolicy", Class.new(ApplicationPolicy) {
        def edit? = user.roles.include?(:update_team)
        alias_method :update?, :edit?
      })
      RailsAdminNext.config Team do
        field :players do
          associated_collection_scope do
            team = bindings[:object]
            proc { |scope| scope.where(team_id: team&.id) }
          end
        end
      end
    end

    def picked_player_ids(**params)
      get index_path(model_name: "player", compact: true, format: :json, associated_collection: "players", source_abstract_model: "team", **params)
      JSON.parse(response.body).map { it["id"].to_i }
    end

    it "lists without the source record when the user may not edit it" do
      @user.update(roles: %i[admin])
      expect(picked_player_ids(current_action: "update", source_object_id: team.id)).to contain_exactly(teammate.id, free_agent.id)
    end

    it "judges a source record named on a create form the same way" do
      @user.update(roles: %i[admin])
      expect(picked_player_ids(current_action: "create", source_object_id: team.id)).to contain_exactly(teammate.id, free_agent.id)
    end

    it "scopes by the source record the user may edit" do
      @user.update(roles: %i[admin update_team])
      expect(picked_player_ids(current_action: "update", source_object_id: team.id)).to contain_exactly(teammate.id)
    end

    it "lists without the source record when the host has no edit action" do
      @user.update(roles: %i[admin update_team])
      RailsAdminNext.config do |c|
        c.actions do
          dashboard
          index
          new
        end
      end
      expect(picked_player_ids(current_action: "create", source_object_id: team.id)).to contain_exactly(teammate.id, free_agent.id)
    end

    it "scopes a new-record picker with no source record" do
      @user.update(roles: %i[admin])
      expect(picked_player_ids(current_action: "create")).to contain_exactly(free_agent.id)
    end

    it "lists without a source record that does not exist" do
      @user.update(roles: %i[admin update_team])
      expect(picked_player_ids(current_action: "update", source_object_id: 0)).to contain_exactly(teammate.id, free_agent.id)
    end

    it "answers a denied source record exactly as a missing one" do
      @user.update(roles: %i[admin])
      picked_player_ids(current_action: "update", source_object_id: team.id)
      denied = response.body
      picked_player_ids(current_action: "update", source_object_id: 0)
      expect(response.body).to eq(denied)
    end

    it "lists without a source record outside the model's scope" do
      @user.update(roles: %i[admin update_team])
      excluded = team.id
      RailsAdminNext.config(Team) { scope { Team.where.not(id: excluded) } }
      expect(picked_player_ids(current_action: "update", source_object_id: team.id)).to contain_exactly(teammate.id, free_agent.id)
    end
  end

  describe "association picker inside a nested form" do
    let!(:player) { FactoryBot.create(:player) }
    let!(:draft) { FactoryBot.create(:draft, player:) }
    let!(:other_draft) { FactoryBot.create(:draft) }

    before do
      stub_const("DraftPolicy", Class.new(ApplicationPolicy) {
        def edit? = false
        alias_method :update?, :edit?
      })
      stub_const("TeamPolicy", Class.new(ApplicationPolicy) {
        const_set(:Scope, Class.new(ApplicationPolicy::Scope) { def resolve = scope.all })
        def index? = user.roles.include?(:admin)
      })
      RailsAdminNext.config Draft do
        field :team do
          associated_collection_scope do
            source = bindings[:object]
            proc { |scope| scope.where(id: source&.team_id) }
          end
        end
      end
    end

    def picked_team_ids(source, parents)
      get index_path(model_name: "team", compact: true, format: :json, associated_collection: "team", source_abstract_model: "draft",
        current_action: "update", source_object_id: source.id, source_parents: parents)
      JSON.parse(response.body).map { it["id"].to_i }
    end

    it "sends the parent record with the subform's picker" do
      @user.update(roles: %i[admin update_player])
      get edit_path(model_name: "nested_player", id: player.id)
      sources = Nokogiri::HTML(response.body).css("[data-filtering-select-options-value]").map do |select|
        Rack::Utils.parse_nested_query(URI(JSON.parse(select["data-filtering-select-options-value"])["remote_source"]).query)
      end
      expect(sources).to include(a_hash_including("source_object_id" => draft.id.to_s, "source_parents" => [{"model" => "nested_player", "id" => player.id.to_s}]))
    end

    it "scopes by a subform record the user edits through its parent" do
      @user.update(roles: %i[admin update_player])
      expect(picked_team_ids(draft, [{model: "nested_player", id: player.id}])).to eq([draft.team_id])
    end

    it "lists without a subform record when the user may not edit its parent" do
      @user.update(roles: %i[admin])
      expect(picked_team_ids(draft, [{model: "nested_player", id: player.id}])).to contain_exactly(draft.team_id, other_draft.team_id)
    end

    it "lists without a record that does not belong to the named parent" do
      @user.update(roles: %i[admin update_player])
      expect(picked_team_ids(other_draft, [{model: "nested_player", id: player.id}])).to contain_exactly(draft.team_id, other_draft.team_id)
    end

    it "lists without a parent the model does not nest the record under" do
      @user.update(roles: %i[admin update_player])
      expect(picked_team_ids(draft, [{model: "player", id: player.id}])).to contain_exactly(draft.team_id, other_draft.team_id)
    end

    it "lists without a subform record the parent's update form does not nest" do
      @user.update(roles: %i[admin update_player])
      RailsAdminNext.config(NestedPlayer) { update { exclude_fields :draft } }
      expect(picked_team_ids(draft, [{model: "nested_player", id: player.id}])).to contain_exactly(draft.team_id, other_draft.team_id)
    end

    it "binds the view while judging the parent's fields" do
      @user.update(roles: %i[admin update_player])
      RailsAdminNext.config(NestedPlayer) { configure(:name) { visible { bindings[:view]._current_user.present? } } }
      expect(picked_team_ids(draft, [{model: "nested_player", id: player.id}])).to eq([draft.team_id])
    end

    it "lists without a subform record when the parent chain is malformed", :aggregate_failures do
      @user.update(roles: %i[admin update_player])
      get index_path(model_name: "team", compact: true, format: :json, associated_collection: "team", source_abstract_model: "draft",
        current_action: "update", source_object_id: draft.id, source_parents: "nested_player")
      expect(response).to have_http_status(:ok)
      expect(picked_team_ids(draft, [{model: "nested_player"}])).to contain_exactly(draft.team_id, other_draft.team_id)
    end
  end

  describe "association picker inside a nested collection" do
    let!(:field_test) { FieldTest.create! }
    let!(:another_field_test) { FieldTest.create! }
    let!(:nested) { NestedFieldTest.create!(field_test:) }
    let!(:deeply_nested) { DeeplyNestedFieldTest.create!(nested_field_test: nested) }
    let!(:other_nested) { NestedFieldTest.create!(field_test: another_field_test) }

    before do
      stub_const("FieldTestPolicy", Class.new(ApplicationPolicy) {
        const_set(:Scope, Class.new(ApplicationPolicy::Scope) { def resolve = scope.all })
        def index? = user.roles.include?(:admin)
        def edit? = user.roles.include?(:update_field_test)
        alias_method :update?, :edit?
      })
      stub_const("NestedFieldTestPolicy", Class.new(ApplicationPolicy) {
        const_set(:Scope, Class.new(ApplicationPolicy::Scope) { def resolve = scope.all })
        def index? = user.roles.include?(:admin)
        def edit? = false
        alias_method :update?, :edit?
      })
      stub_const("DeeplyNestedFieldTestPolicy", Class.new(ApplicationPolicy) {
        def edit? = false
        alias_method :update?, :edit?
      })
      RailsAdminNext.config NestedFieldTest do
        configure :field_test do
          associated_collection_scope do
            source = bindings[:object]
            proc { |scope| scope.where(id: source&.field_test_id) }
          end
        end
      end
      RailsAdminNext.config DeeplyNestedFieldTest do
        configure :nested_field_test do
          associated_collection_scope do
            source = bindings[:object]
            proc { |scope| scope.where(id: source&.nested_field_test_id) }
          end
        end
      end
    end

    def picked_ids(model_name, collection, source, parents)
      get index_path(model_name:, compact: true, format: :json, associated_collection: collection, source_abstract_model: source.class.name.underscore,
        current_action: "update", source_object_id: source.id, source_parents: parents)
      JSON.parse(response.body).map { it["id"].to_i }
    end

    it "scopes by a record of the parent's nested collection" do
      @user.update(roles: %i[admin update_field_test])
      expect(picked_ids("field_test", "field_test", nested, [{model: "field_test", id: field_test.id}])).to eq([field_test.id])
    end

    it "lists without a record outside the parent's nested collection" do
      @user.update(roles: %i[admin update_field_test])
      expect(picked_ids("field_test", "field_test", other_nested, [{model: "field_test", id: field_test.id}])).to contain_exactly(field_test.id, another_field_test.id)
    end

    it "scopes a record two levels down through the editable grandparent" do
      @user.update(roles: %i[admin update_field_test])
      parents = [{model: "nested_field_test", id: nested.id}, {model: "field_test", id: field_test.id}]
      expect(picked_ids("nested_field_test", "nested_field_test", deeply_nested, parents)).to eq([nested.id])
    end

    it "lists without a record two levels down when the grandparent is not named" do
      @user.update(roles: %i[admin update_field_test])
      expect(picked_ids("nested_field_test", "nested_field_test", deeply_nested, [{model: "nested_field_test", id: nested.id}])).to contain_exactly(nested.id, other_nested.id)
    end

    it "lists without a record the middle parent's nested form does not show" do
      @user.update(roles: %i[admin update_field_test])
      RailsAdminNext.config(NestedFieldTest) { nested { exclude_fields :deeply_nested_field_tests } }
      parents = [{model: "nested_field_test", id: nested.id}, {model: "field_test", id: field_test.id}]
      expect(picked_ids("nested_field_test", "nested_field_test", deeply_nested, parents)).to contain_exactly(nested.id, other_nested.id)
    end
  end

  context "when the host controller overrides policy_scope with one argument" do
    it "lists through the override", :aggregate_failures do
      @user.update(roles: %i[admin manage_player])
      FactoryBot.create :player, name: "Alice"
      FactoryBot.create :player, name: "Bob", retired: true
      allow_any_instance_of(RailsAdminNext::MainController).to receive(:policy_scope, &->(_controller, scope) { scope.where(retired: false) })
      visit index_path(model_name: "player")
      is_expected.to have_content("Alice")
      is_expected.not_to have_content("Bob")
    end

    it "lists nothing when the override names a scope that does not exist" do
      @user.update(roles: %i[admin manage_player])
      FactoryBot.create :player, name: "Alice"
      allow_any_instance_of(RailsAdminNext::MainController).to receive(:policy_scope).and_wrap_original { |original, scope| original.call([:admin, scope]) }
      visit index_path(model_name: "player")
      is_expected.not_to have_content("Alice")
    end
  end

  context "when ApplicationController already has pundit_user" do
    let(:admin) { FactoryBot.create :user, roles: [:admin] }
    before do
      RailsAdminNext.config.parent_controller = "ApplicationController"
      allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(admin)
    end

    it "uses original pundit_user" do
      pending "no way to dynamically change superclass"
      expect { visit dashboard_path }.not_to raise_error
    end
  end

  context "when custom authorization key is set" do
    before do
      RailsAdminNext.config do |c|
        c.actions do
          dashboard
          index do
            authorization_key :rails_admin_index
          end
        end
      end
    end

    it "uses the custom key" do
      expect { visit index_path(model_name: "team") }.not_to raise_error
    end

    it "lists no records of a model with no policy Scope" do
      team = FactoryBot.create :team
      visit index_path(model_name: "team")
      is_expected.not_to have_content(team.name)
    end

    it "lists no records of a model with no policy Scope under a tab that drops conditions" do
      team = FactoryBot.create :team
      RailsAdminNext.config Team do
        list { scopes [nil, :unscoped] }
      end
      visit index_path(model_name: "team", scope: "unscoped")
      is_expected.not_to have_content(team.name)
    end
  end

  describe "an STI subclass with no policy of its own" do
    before do
      stub_const("BallPolicy", StiBallPolicy)
      @user.update(roles: [:admin])
      RailsAdminNext.config do |c|
        c.actions do
          dashboard
          index { authorization_key :rails_admin_index }
          show
        end
      end
      @red = FactoryBot.create :hardball, color: "red"
      @blue = FactoryBot.create :hardball, color: "blue"
    end

    it "is denied what its parent model's policy denies" do
      expect { visit show_path(model_name: "hardball", id: @red.id) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "is listed through its parent model's policy Scope", :aggregate_failures do
      visit index_path(model_name: "hardball")
      is_expected.to have_css("input[name='bulk_ids[]'][value='#{@red.id}']")
      is_expected.not_to have_css("input[name='bulk_ids[]'][value='#{@blue.id}']")
    end

    it "uses a policy of its own over its parent model's" do
      stub_const("HardballPolicy", Class.new(ApplicationPolicy))
      visit show_path(model_name: "hardball", id: @red.id)
      is_expected.to have_content("Details")
    end

    it "lists nothing when its own policy has no Scope, rather than taking its parent model's" do
      stub_const("HardballPolicy", Class.new {
        def initialize(_user, _record) = nil

        def rails_admin_index? = true

        def show? = true
      })
      visit index_path(model_name: "hardball")
      is_expected.not_to have_css("input[name='bulk_ids[]'][value='#{@red.id}']")
    end

    it "takes its parent model's policy through a host override of policy" do
      hide_const("BallPolicy")
      stub_const("Admin::BallPolicy", StiBallPolicy)
      allow_any_instance_of(RailsAdminNext::MainController).to receive(:policy).and_wrap_original { |original, record| original.call([:admin, record]) }
      expect { visit show_path(model_name: "hardball", id: @red.id) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "lists nothing when no model in its hierarchy has a policy" do
      hide_const("BallPolicy")
      visit index_path(model_name: "hardball")
      is_expected.not_to have_css("input[name='bulk_ids[]'][value='#{@red.id}']")
    end
  end

  {
    "nil" => [->(_) {}, true],
    "a hash" => [->(_) { {} }, false],
    "a proc" => [->(_) { -> {} }, true],
    "an array" => [->(scope) { scope.to_a }, false]
  }.each do |label, (resolve, counted_on_dashboard)|
    describe "a policy Scope that resolves to #{label}", active_record: true do
      before do
        policy = Class.new(PlayerPolicy)
        policy.const_set(:Scope, Class.new(PlayerPolicy::Scope) { define_method(:resolve) { resolve.call(scope) } })
        stub_const("PlayerPolicy", policy)
        @user.update(roles: %i[admin export_player])
      end

      it_behaves_like "an authorization scope that is not a relation", counted_on_dashboard:
    end

    describe "a history policy Scope that resolves to #{label}", active_record: true do
      before do
        policy = Class.new(ScopedPaperTrailTestPolicy)
        policy.const_set(:Scope, Class.new(ScopedPaperTrailTestPolicy::Scope) { define_method(:resolve) { resolve.call(scope) } })
        stub_const("PaperTrailTestPolicy", policy)
        @user.update(roles: %i[admin])
      end

      it_behaves_like "history under an authorization scope that is not a relation"
    end
  end

  context "when custom authorization key is suffixed with ?" do
    before do
      @user.update(roles: [:admin])
      RailsAdminNext.config do |c|
        c.actions do
          dashboard do
            authorization_key :dashboard?
          end
          index
        end
      end
    end

    it "does not append ? on policy check" do
      expect_any_instance_of(ApplicationPolicy).not_to receive(:"dashboard??")
      visit dashboard_path
    end
  end
end
