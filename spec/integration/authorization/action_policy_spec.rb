# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAdminNext ActionPolicy Authorization", type: :request do
  subject { page }

  before do
    stub_const("ApplicationPolicy", ActionPolicies::ApplicationPolicy)
    stub_const("PlayerPolicy", ActionPolicies::PlayerPolicy)
    stub_const("TeamPolicy", ActionPolicies::TeamPolicy)
    stub_const("DivisionPolicy", ActionPolicies::DivisionPolicy)
    RailsAdminNext.config do |c|
      c.authorize_with(:action_policy)
      c.authenticate_with { warden.authenticate! scope: :user }
      c.current_user_method(&:current_user)
    end
    @player_model = RailsAdminNext::AbstractModel.new(Player)
    @user = FactoryBot.create :user, roles: []
    login_as @user
  end

  describe "with no roles" do
    it "GET /admin raises ActionPolicy::Unauthorized" do
      expect { visit dashboard_path }.to raise_error(ActionPolicy::Unauthorized)
    end

    it "GET /admin/player raises ActionPolicy::Unauthorized" do
      expect { visit index_path(model_name: "player") }.to raise_error(ActionPolicy::Unauthorized)
    end
  end

  describe "with read player role" do
    before do
      @user.update(roles: %i[admin read_player])
    end

    it "GET /admin shows Player but not League" do
      visit dashboard_path
      is_expected.to have_content("Player")
      is_expected.not_to have_content("League")
      is_expected.not_to have_content("Add new")
    end

    it "GET /admin/league, a model with no policy, raises ActionPolicy::Unauthorized" do
      expect { visit index_path(model_name: "league") }.to raise_error(ActionPolicy::Unauthorized)
    end

    it "GET /admin/player/1/edit raises ActionPolicy::Unauthorized" do
      @player = FactoryBot.create :player
      expect { visit edit_path(model_name: "player", id: @player.id) }.to raise_error(ActionPolicy::Unauthorized)
    end
  end

  describe "with update player role" do
    it "GET /admin/player/1/edit renders the form" do
      @user.update(roles: %i[admin update_player])
      @player = FactoryBot.create :player, retired: false
      visit edit_path(model_name: "player", id: @player.id)
      is_expected.to have_button("Save")
    end
  end

  describe "with admin role" do
    before do
      @user.update(roles: %i[admin manage_player])
    end

    it "GET /admin renders the dashboard" do
      visit dashboard_path
      is_expected.to have_content("Player")
    end

    it "GET /admin/player/new renders and creates a record upon submission", :aggregate_failures do
      visit index_path(model_name: "player")
      is_expected.to have_content("Add new")

      visit new_path(model_name: "player")
      is_expected.to have_content("Save and edit")
      is_expected.not_to have_content("Delete")
      fill_in "player[name]", with: "Jackie Robinson"
      fill_in "player[number]", with: "42"
      fill_in "player[position]", with: "Second baseman"
      click_button "Save"

      @player = RailsAdminNext::AbstractModel.new("Player").first
      expect(@player.name).to eq("Jackie Robinson")
      expect(@player.number).to eq(42)
      expect(@player.position).to eq("Second baseman")
    end

    it "GET /admin/player/new prefills the policy's attributes_for" do
      visit new_path(model_name: "player")
      expect(find_field("player[position]").value).to eq("Catcher")
    end

    it "shows links to all actions" do
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
    it "POST /admin/player/new with an unauthorized attribute value raises ActionPolicy::Unauthorized" do
      @user.update(roles: %i[admin read_player create_player])
      visit new_path(model_name: "player")
      fill_in "player[name]", with: "Jackie Robinson"
      choose name: "player[suspended]", option: "0"
      expect { click_button "Save" }.to raise_error(ActionPolicy::Unauthorized)
    end
  end

  describe "with update and read player role" do
    it "PUT /admin/player/1/edit with an unauthorized attribute value raises ActionPolicy::Unauthorized" do
      @user.update(roles: %i[admin read_player update_player])
      @player = FactoryBot.create :player
      visit edit_path(model_name: "player", id: @player.id)
      choose name: "player[retired]", option: "1"
      expect { click_button "Save" }.to raise_error(ActionPolicy::Unauthorized)
    end
  end

  describe "the relation scope" do
    before do
      %w[Charlie Alice].each { FactoryBot.create :player, name: it }
      FactoryBot.create :player, name: "Bob", retired: true
    end

    it "narrows the list and the dashboard count", :aggregate_failures do
      @user.update(roles: %i[admin read_player])

      visit index_path(model_name: "player")
      is_expected.to have_content("Alice")
      is_expected.to have_content("Charlie")
      is_expected.not_to have_content("Bob")

      visit dashboard_path
      expect(find("tr.player_links .progress-bar")).to have_text(/\A\s*2\s*\z/)
    end

    it "narrows the export" do
      @user.update(roles: %i[admin read_player])
      RailsAdminNext.config(Player) do
        export do
          field :name
        end
      end
      stub_const("RailsAdminNext::CSVConverter::BATCH_SIZE", 1)

      page.driver.post(export_path(model_name: "player", schema: {only: ["name"]}, csv: true, all: true, sort: "name", csv_options: {generator: {col_sep: ","}}))

      expect(CSV.parse(page.driver.response.body)).to eq [["Name"], ["Alice"], ["Charlie"]]
    end

    it "comes from the policy a model names with policy_class", :aggregate_failures do
      @user.update(roles: %i[admin read_player])
      allow(Player).to receive(:policy_class).and_return(ActionPolicies::RetiredPlayerPolicy)
      visit index_path(model_name: "player")
      is_expected.to have_content("Bob")
      is_expected.not_to have_content("Alice")
    end

    it "is applied for the configured current user" do
      @user.update(roles: %i[admin read_player see_retired])
      visit index_path(model_name: "player")
      is_expected.to have_content("Bob")
    end

    context "with the destroy player role" do
      before do
        @user.update(roles: %i[admin manage_player])
        @active = Player.find_by!(name: "Alice")
        @retired = Player.find_by!(name: "Bob")
      end

      it "renders only scoped records for bulk delete", :aggregate_failures do
        post bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: [@active, @retired].collect(&:id))
        expect(response.body).to include(@active.name)
        expect(response.body).not_to include(@retired.name)
      end

      it "bulk destroys only scoped records", :aggregate_failures do
        delete bulk_delete_path(model_name: "player", bulk_ids: [@active, @retired].collect(&:id))
        expect(@player_model.get(@active.id)).to be_nil
        expect(@player_model.get(@retired.id)).not_to be_nil
      end

      it "does not let a tab that drops conditions destroy records outside the scope" do
        RailsAdminNext.config Player do
          list { scopes [nil, :unscoped] }
        end
        delete bulk_delete_path(model_name: "player", scope: "unscoped", bulk_ids: [@active, @retired].collect(&:id))
        expect(@player_model.get(@retired.id)).not_to be_nil
      end
    end
  end

  context "with a custom current_user_method" do
    it "authorizes the user that method returns, not the signed-in one" do
      admin = FactoryBot.create :user, roles: %i[admin read_player]
      RailsAdminNext.config do |c|
        c.current_user_method { admin }
      end
      visit dashboard_path
      is_expected.to have_content("Player")
    end
  end

  context "when custom authorization key is set" do
    before do
      @user.update(roles: [:admin])
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

    it "lists no records of a model whose policy has no relation scope" do
      team = FactoryBot.create :team
      visit index_path(model_name: "team")
      is_expected.not_to have_content(team.name)
    end

    it "lists no records of a model whose policy has no relation scope under a tab that drops conditions" do
      team = FactoryBot.create :team
      RailsAdminNext.config Team do
        list { scopes [nil, :unscoped] }
      end
      visit index_path(model_name: "team", scope: "unscoped")
      is_expected.not_to have_content(team.name)
    end

    it "lists no records of a model whose policy has only a named relation scope" do
      division = FactoryBot.create :division
      visit index_path(model_name: "division")
      is_expected.not_to have_content(division.name)
    end

    it "lists no records of a model with no policy" do
      league = FactoryBot.create :league
      visit index_path(model_name: "league")
      is_expected.not_to have_content(league.name)
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
      expect_any_instance_of(ActionPolicies::ApplicationPolicy).not_to receive(:"dashboard??")
      visit dashboard_path
      is_expected.to have_content("Player")
    end
  end
end
