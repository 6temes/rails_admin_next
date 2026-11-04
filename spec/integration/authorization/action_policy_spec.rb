# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAdminNext ActionPolicy Authorization", type: :request do
  subject { page }

  before do
    stub_const("ApplicationPolicy", ActionPolicies::ApplicationPolicy)
    stub_const("PlayerPolicy", ActionPolicies::PlayerPolicy)
    stub_const("TeamPolicy", ActionPolicies::TeamPolicy)
    stub_const("DivisionPolicy", ActionPolicies::DivisionPolicy)
    # A Pundit policy left in place would be looked up by name and fail on ActionPolicy calls.
    hide_const("FanshipPolicy")
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

  describe "history of records outside the relation scope", active_record: true do
    before { @user.update(roles: %i[admin]) }

    it_behaves_like "history within the authorization scope", ActionPolicies::PaperTrailTestPolicy
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

      context "with a destroy? rule that depends on the record" do
        before do
          allow(Player).to receive(:policy_class).and_return(ActionPolicies::SuspendedPlayerPolicy)
          @suspended = FactoryBot.create :player, name: "Dana", suspended: true
        end

        it "refuses a single delete" do
          expect { visit delete_path(model_name: "player", id: @suspended.id) }.to raise_error(ActionPolicy::Unauthorized)
        end

        it "does not list records destroy? refuses for bulk delete", :aggregate_failures do
          post bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: [@active, @suspended].collect(&:id))
          expect(response.body).to include(@active.name)
          expect(response.body).not_to include(@suspended.name)
        end

        it "bulk destroy leaves records destroy? refuses and counts them as failed", :aggregate_failures do
          delete bulk_delete_path(model_name: "player", bulk_ids: [@active, @suspended].collect(&:id))
          expect(@player_model.get(@active.id)).to be_nil
          expect(@player_model.get(@suspended.id)).not_to be_nil
          expect(flash[:success]).to eq "1 Player successfully deleted"
          expect(flash[:error]).to eq "1 Player failed to be deleted"
        end
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

  {
    "nil" => [->(_) {}, true],
    "a hash" => [->(_) { {} }, false],
    "a proc" => [->(_) { -> {} }, true],
    "an array" => [->(scope) { scope.to_a }, false]
  }.each do |label, (resolve, counted_on_dashboard)|
    describe "a relation scope that resolves to #{label}", active_record: true do
      before do
        stub_const("PlayerPolicy", Class.new(ActionPolicies::PlayerPolicy) {
          def self.name = "PlayerPolicy"

          relation_scope { |relation| resolve.call(relation) }
        })
        @user.update(roles: %i[admin])
      end

      it_behaves_like "an authorization scope that is not a relation", counted_on_dashboard:
    end

    describe "a history relation scope that resolves to #{label}", active_record: true do
      before do
        stub_const("PaperTrailTestPolicy", Class.new(ActionPolicies::PaperTrailTestPolicy) {
          def self.name = "PaperTrailTestPolicy"

          relation_scope { |relation| resolve.call(relation) }
        })
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
      expect_any_instance_of(ActionPolicies::ApplicationPolicy).not_to receive(:"dashboard??")
      visit dashboard_path
      is_expected.to have_content("Player")
    end
  end

  describe "an STI subclass with no policy of its own" do
    before do
      stub_const("BallPolicy", ActionPolicies::BallPolicy)
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
      expect { visit show_path(model_name: "hardball", id: @red.id) }.to raise_error(ActionPolicy::Unauthorized)
    end

    it "is listed through its parent model's policy Scope", :aggregate_failures do
      visit index_path(model_name: "hardball")
      is_expected.to have_css("input[name='bulk_ids[]'][value='#{@red.id}']")
      is_expected.not_to have_css("input[name='bulk_ids[]'][value='#{@blue.id}']")
    end

    it "uses a policy of its own over its parent model's" do
      stub_const("HardballPolicy", Class.new(ActionPolicies::ApplicationPolicy) { def self.name = "HardballPolicy" })
      visit show_path(model_name: "hardball", id: @red.id)
      is_expected.to have_content("Details")
    end

    it "lists nothing when no policy in its hierarchy has a relation scope" do
      stub_const("BallPolicy", ActionPolicies::TeamPolicy)
      visit index_path(model_name: "hardball")
      is_expected.not_to have_css("input[name='bulk_ids[]'][value='#{@red.id}']")
    end
  end

  describe "with an authorization context beyond the user" do
    before do
      stub_const("PlayerPolicy", ActionPolicies::AccountPlayerPolicy)
      @user.update(roles: %i[admin read_player update_player create_player])
      @own_team = FactoryBot.create :team, manager: @user.email
      @other_team = FactoryBot.create :team
      @own_player = FactoryBot.create :player, team: @own_team
      @other_player = FactoryBot.create :player, team: @other_team
    end

    def configure_context(context)
      RailsAdminNext.config { |c| c.authorize_with(:action_policy, context:) }
    end

    it "scopes the list by the account the context resolves on the controller", :aggregate_failures do
      configure_context(account: -> { Team.find_by(manager: _current_user.email) })
      visit index_path(model_name: "player")
      is_expected.to have_content(@own_player.name)
      is_expected.not_to have_content(@other_player.name)
    end

    it "resolves the context again on each request", :aggregate_failures do
      configure_context(account: -> { Team.find_by(manager: _current_user.email) })
      visit index_path(model_name: "player")
      @own_team.update!(manager: "Someone else")
      @other_team.update!(manager: @user.email)
      visit index_path(model_name: "player")
      is_expected.to have_content(@other_player.name)
      is_expected.not_to have_content(@own_player.name)
    end

    it "raises from every adapter entry point when the context resolves to nil", :aggregate_failures do
      configure_context(account: -> {})
      controller = Struct.new(:_current_user).new(@user)
      adapter = RailsAdminNext::Extensions::ActionPolicy::AuthorizationAdapter.new(controller, context: {account: -> {}})
      player_model = RailsAdminNext::AbstractModel.new(Player)
      expect { adapter.query(:index, player_model) }.to raise_error(ActionPolicy::AuthorizationContextMissing)
      expect { adapter.authorize(:edit, player_model, @own_player) }.to raise_error(ActionPolicy::AuthorizationContextMissing)
      expect { adapter.authorized?(:show, player_model, @own_player) }.to raise_error(ActionPolicy::AuthorizationContextMissing)
      expect { adapter.attributes_for(:new, player_model) }.to raise_error(ActionPolicy::AuthorizationContextMissing)
      expect { visit index_path(model_name: "player") }.to raise_error(ActionPolicy::AuthorizationContextMissing)
    end

    it "still lists nothing for a model whose policy has no relation scope" do
      configure_context(account: -> { Team.find_by(manager: _current_user.email) })
      RailsAdminNext.config do |c|
        c.actions do
          dashboard
          index { authorization_key :rails_admin_index }
        end
      end
      visit index_path(model_name: "team")
      is_expected.not_to have_content(@other_team.name)
    end
  end
end
