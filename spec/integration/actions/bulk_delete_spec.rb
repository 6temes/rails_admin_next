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

  context "when a destroy raises an unexpected error mid-batch", active_record: true do
    # Created in reverse: the batch runs in the list's default id-descending order.
    let!(:failing) { FactoryBot.create(:player) }
    let!(:destroyed_first) { FactoryBot.create(:player) }

    before do
      RailsAdminNext.config do |config|
        config.audit_with :paper_trail
      end
      allow_any_instance_of(Player).to receive(:destroy_hook) do |player|
        raise ActiveRecord::StatementInvalid, "boom" if player.id == failing.id
      end
    end

    it "audits the records destroyed before the error" do
      audited = []
      allow_any_instance_of(RailsAdminNext::Extensions::PaperTrail::AuditingAdapter).to receive(:delete_object) { |_adapter, object| audited << object.id }

      expect {
        delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: [destroyed_first.id, failing.id]))
      }.to raise_error(ActiveRecord::StatementInvalid, "boom")

      expect(Player.where(id: destroyed_first.id)).not_to exist
      expect(audited).to eq [destroyed_first.id]
    end
  end

  # The confirmation form's own fields, submitted the way the browser would.
  def confirmation_fields(button: nil)
    form = Nokogiri::HTML(response.body).at_css("form[action*='bulk_delete']")
    pairs = form.css("input[type=hidden]:not([name=_method])").map { [it["name"], it["value"].to_s] }
    pairs << [button, ""] if button
    [form["action"], Rack::Utils.parse_nested_query(URI.encode_www_form(pairs))]
  end

  def submit_confirmation(button: nil)
    action, fields = confirmation_fields(button:)
    delete(action, params: fields)
  end

  def hidden_value(name)
    Nokogiri::HTML(response.body).at_css("form[action*='bulk_delete'] input[type=hidden][name='#{name}']")&.[]("value")
  end

  def count_queries(&)
    counts = []
    counter = ->(*, payload) { counts << payload[:sql] if payload[:sql].match?(/\bCOUNT\(/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    counts
  end

  describe "acting on every matching record" do
    let!(:smiths) { %w[Alice Bea Carol].map { FactoryBot.create :player, name: "#{it} Smithfield" } }
    let!(:outsiders) { %w[Dora Erin].map { FactoryBot.create :player, name: "#{it} Outsider" } }
    let(:flagged) { {all_matching: "true", query: "Smithfield"} }

    def confirm_all_matching(**params)
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "player", **flagged, **params))
    end

    it "confirms by count and deletes the matching records with the form's fields", :aggregate_failures do
      confirm_all_matching

      expect(response.body).to include("3 Players will be deleted")
      (smiths + outsiders).each { expect(response.body).not_to include(it.name) }
      expect(Nokogiri::HTML(response.body).css("input[name='bulk_ids[]']")).to be_empty
      expect(hidden_value("all_matching")).to eq "true"
      expect(hidden_value("query")).to eq "Smithfield"
      expect(hidden_value("expected_count")).to eq "3"

      submit_confirmation
      expect(flash[:success]).to eq "3 Players successfully deleted"
      expect(Player.all).to match_array outsiders
    end

    it "runs one COUNT against the players table and loads no player", :aggregate_failures do
      loaded = 0
      counter = ->(*, payload) { loaded += payload[:record_count] if payload[:class_name] == "Player" }
      counts = ActiveSupport::Notifications.subscribed(counter, "instantiation.active_record") do
        count_queries { confirm_all_matching }
      end

      expect(response).to have_http_status(:ok)
      expect(counts.grep(/players/)).to be_one
      expect(loaded).to eq 0
    end

    it "runs exactly one COUNT on a limited_pagination model" do
      RailsAdminNext.config Player do
        list { limited_pagination true }
      end

      expect(count_queries { confirm_all_matching }).to be_one
    end

    it "deletes nothing and shows the new count when the set changed", :aggregate_failures do
      confirm_all_matching
      FactoryBot.create :player, name: "Dan Smithfield"

      expect { submit_confirmation }.not_to change(Player, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("4 Players will be deleted")
      expect(response.body).to include("The matching records changed")
      expect(hidden_value("expected_count")).to eq "4"

      submit_confirmation
      expect(flash[:success]).to eq "4 Players successfully deleted"
      expect(Player.all).to match_array outsiders
    end

    it "answers a re-count of zero with the empty-set error" do
      delete(bulk_delete_path(model_name: "player", all_matching: "true", query: "Nobody", expected_count: "3"))
      expect(response.response_code).to eq 302
      expect(flash[:error]).to eq "0 Players failed to be deleted"
    end

    it "redirects with the empty-set error when nothing matches", :aggregate_failures do
      confirm_all_matching(query: "Nobody")
      expect(response).to redirect_to(index_path(model_name: "player"))
      expect(flash[:error]).to eq "0 Players failed to be deleted"
    end

    it "deletes every matching record whatever sort the payload carries" do
      delete(bulk_delete_path(model_name: "player", **flagged, sort: "name", expected_count: "3"))
      expect(Player.all).to match_array outsiders
    end

    it "leaves a matching player created while the slices are being destroyed", :aggregate_failures do
      stub_const("RailsAdminNext::Config::Actions::BulkDelete::SLICE_SIZE", 1)
      late = nil
      allow_any_instance_of(Player).to receive(:destroy_hook) { late ||= FactoryBot.create(:player, name: "Eve Smithfield") }

      delete(bulk_delete_path(model_name: "player", **flagged, expected_count: "3"))

      expect(flash[:success]).to eq "3 Players successfully deleted"
      expect(Player.all).to match_array outsiders + [late]
    end

    it "audits each destroyed record" do
      RailsAdminNext.config do |config|
        config.audit_with :paper_trail
      end
      expect_any_instance_of(RailsAdminNext::Extensions::PaperTrail::AuditingAdapter).to receive(:delete_object).exactly(3).times

      delete(bulk_delete_path(model_name: "player", **flagged, expected_count: "3"))
    end

    it "carries data-turbo-confirm with the count sentence on its submit" do
      confirm_all_matching
      button = Nokogiri::HTML(response.body).at_css("form[action*='bulk_delete'] button[type=submit]:not([name])")
      expect(button["data-turbo-confirm"]).to start_with "3 Players will be deleted"
    end

    it "deletes nothing when the count confirmation is cancelled", :aggregate_failures do
      confirm_all_matching
      expect { submit_confirmation(button: "_continue") }.not_to change(Player, :count)
      expect(flash[:notice]).to eq "No actions were taken"
    end

    it "counts a record matched through two associated rows once", :aggregate_failures do
      RailsAdminNext.config Player do
        list do
          field :name
          field :comments do
            queryable true
            searchable :content
          end
        end
      end
      2.times { FactoryBot.create :comment, commentable: smiths.first, content: "zebra crossing" }

      confirm_all_matching(query: "zebra")
      expect(response.body).to include("1 Player will be deleted")
      expect(hidden_value("expected_count")).to eq "1"

      submit_confirmation
      expect(flash[:success]).to eq "1 Player successfully deleted"
      expect(Player.where(id: smiths.first.id)).not_to exist
      expect(Player.count).to eq 4
    end
  end

  describe "acting on every matching record in a scope tab" do
    let!(:red_team) { FactoryBot.create(:team, name: "Red Sox", color: "red") }
    let!(:white_team) { FactoryBot.create(:team, name: "White Sox", color: "white") }

    before do
      RailsAdminNext.config Team do
        list do
          scopes [nil, :red, :white]
        end
      end
    end

    it "deletes only the tab's matching records" do
      delete(bulk_delete_path(model_name: "team", scope: "red", all_matching: "true", expected_count: "1"))
      expect(Team.all).to eq [white_team]
    end
  end

  context "with a record restricted by dependent: :restrict_with_exception, acting on every matching record", active_record: true do
    let!(:restricted) { FactoryBot.create(:player, team: FactoryBot.create(:exception_restricted_team)).team }
    let!(:deletable) { FactoryBot.create :exception_restricted_team }

    it "deletes the others and reports the restricted one", :aggregate_failures do
      delete(bulk_delete_path(model_name: "exception_restricted_team", all_matching: "true", expected_count: "2"))

      expect(flash[:success]).to eq "1 Exception restricted team successfully deleted"
      expect(flash[:error]).to eq "1 Exception restricted team failed to be deleted"
      expect(Team.where(id: restricted.id)).to exist
      expect(Team.where(id: deletable.id)).not_to exist
    end
  end

  describe "explicit selections" do
    let!(:players) { FactoryBot.create_list(:player, 3) }

    it "lists a small selection and carries its ids in hidden fields", :aggregate_failures do
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: players[0..1].map(&:id)))

      players[0..1].each { expect(response.body).to include(it.name) }
      ids = Nokogiri::HTML(response.body).css("form[action*='bulk_delete'] input[name='bulk_ids[]']").map { it["value"] }
      expect(ids).to match_array players[0..1].map { it.id.to_s }
      expect(confirmation_fields.first).not_to include("bulk_ids")
    end

    it "states the count above the listing threshold and deletes the selection", :aggregate_failures do
      stub_const("RailsAdminNext::Config::Actions::BulkDelete::LIST_LIMIT", 2)
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: players.map(&:id)))

      expect(response.body).to include("3 Players will be deleted")
      players.each { expect(response.body).not_to include(it.name) }

      submit_confirmation
      expect(flash[:success]).to eq "3 Players successfully deleted"
      expect(Player.count).to eq 0
    end
  end

  describe "from the selection bar", js: true do
    let!(:smiths) { %w[Alice Bea Carol].map { FactoryBot.create :player, name: "#{it} Smithfield" } }
    let!(:outsider) { FactoryBot.create :player, name: "Dora Outsider" }

    # Two rows a batch, so the three matching players fill the first batch and the offer shows.
    # The second batch loads on its own; waiting for the end keeps it from landing unticked
    # after the header is ticked.
    before do
      RailsAdminNext.config.default_items_per_page = 2
      visit index_path(model_name: "player", query: "Smithfield")
      is_expected.to have_css(".list-end")
      is_expected.to have_css("tbody#list_rows tr", count: 3)
    end

    def delete_selected
      find("button#bulk_menu_toggle").click
      find("#bulk_menu .bulk-link", text: "Delete selected Players").click
    end

    it "confirms every matching player by count and deletes them", :aggregate_failures do
      find("#bulk_form input.toggle").check
      click_button "Select all 3 matching players"
      delete_selected

      is_expected.to have_content "3 Players will be deleted"
      accept_confirm { click_button "Yes, I'm sure" }
      is_expected.to have_content "3 Players successfully deleted"
      expect(Player.all).to eq [outsider]
    end

    it "lists only the one ticked player of the matching set", :aggregate_failures do
      find("input[name='bulk_ids[]'][value='#{smiths.last.id}']").check
      delete_selected

      is_expected.to have_content "The following objects will be deleted"
      is_expected.to have_content "Carol Smithfield"
      is_expected.to have_no_content "Alice Smithfield"
      is_expected.to have_no_content "Bea Smithfield"
    end
  end

  context "with composite primary keys", composite_primary_keys: true do
    let!(:fanships) { FactoryBot.create_list(:fanship, 3) }

    it "provides check boxes for bulk operation" do
      visit index_path(model_name: "fanship")
      fanships.each { |fanship| is_expected.to have_css(%(input[name="bulk_ids[]"][value="#{RailsAdminNext::Support::CompositeKeysSerializer.serialize(fanship.id)}"])) }
    end

    it "deletes the records selected through the confirmation form" do
      post(bulk_action_path(bulk_action: "bulk_delete", model_name: "fanship", bulk_ids: fanships[0..1].map { |fanship| RailsAdminNext::Support::CompositeKeysSerializer.serialize(fanship.id) }))
      submit_confirmation
      expect(flash[:success]).to match(/2 Fanships successfully deleted/)
      expect(Fanship.all).to eq fanships[2..2]
    end

    it "deletes selected records" do
      delete(bulk_delete_path(bulk_action: "bulk_delete", model_name: "fanship", bulk_ids: fanships[0..1].map { |fanship| RailsAdminNext::Support::CompositeKeysSerializer.serialize(fanship.id) }))
      expect(flash[:success]).to match(/2 Fanships successfully deleted/)
      expect(Fanship.all).to eq fanships[2..2]
    end
  end
end
