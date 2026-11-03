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

  describe "a policy Scope that resolves to nil", active_record: true do
    before do
      policy = Class.new(PlayerPolicy)
      policy.const_set(:Scope, Class.new(PlayerPolicy::Scope) { def resolve = nil })
      stub_const("PlayerPolicy", policy)
      @user.update(roles: %i[admin export_player])
    end

    it_behaves_like "an authorization scope that resolves to nil"
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
