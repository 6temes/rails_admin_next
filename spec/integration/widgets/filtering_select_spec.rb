# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Filtering select widget", type: :request, js: true do
  subject { page }

  let!(:teams) { ["Los Angeles Dodgers", "Texas Rangers"].map { |name| FactoryBot.create :team, name: name } }
  let(:player) { FactoryBot.create :player, team: teams[0] }
  before do
    RailsAdminNext.config Player do
      field :team
      field :number
    end
  end

  # Type into the combobox; the controller debounces, so let Capybara retry on the
  # listbox assertions that follow (no fixed sleeps).
  def filter(query, scope: nil)
    input = scope ? find("#{scope} input.ra-filtering-select-input") : find("input.ra-filtering-select-input")
    input.set(query)
  end

  def option_labels
    all('[role="option"]').map(&:text)
  end

  context "on create" do
    before { visit new_path(model_name: "player") }

    it "is initially unset" do
      expect(find("input.ra-filtering-select-input").value).to be_empty
      expect(find("#player_team_id", visible: false).value).to be_empty
    end

    it "exposes combobox/listbox ARIA semantics" do
      input = find("input.ra-filtering-select-input")
      expect(input["role"]).to eq "combobox"
      expect(input["aria-expanded"]).to eq "false"
      filter("ge")
      expect(page).to have_selector('[role="listbox"] [role="option"]')
      expect(input["aria-expanded"]).to eq "true"
    end

    it "supports filtering" do
      filter("ge")
      expect(page).to have_selector('[role="option"]', count: 2)
      expect(option_labels).to match_array ["Los Angeles Dodgers", "Texas Rangers"]
      filter("Los")
      expect(page).to have_selector('[role="option"]', count: 1)
      expect(option_labels).to eq ["Los Angeles Dodgers"]
      filter("Mets")
      expect(page).to have_selector('[role="option"]', text: "No objects found")
      expect(option_labels).to match_array ["No objects found"]
    end

    it "sets id of the selected item" do
      filter("Tex")
      expect(page).to have_selector('[role="option"]')
      find('[role="option"]', text: "Texas Rangers").click
      expect(find("#player_team_id", visible: false).value).to eq teams[1].id.to_s
    end

    it "selects with the keyboard (arrow + Enter)" do
      input = find("input.ra-filtering-select-input")
      filter("Tex")
      expect(page).to have_selector('[role="option"]', text: "Texas Rangers")
      input.send_keys(:down)
      active = find('[role="option"][aria-selected="true"]')
      expect(input["aria-activedescendant"]).to eq active[:id]
      input.send_keys(:enter)
      expect(find("#player_team_id", visible: false).value).to eq teams[1].id.to_s
    end
  end

  context "on update" do
    it "changes the selected value" do
      visit edit_path(model_name: "player", id: player.id)
      expect(find("#player_team_id", visible: false).value).to eq teams[0].id.to_s
      filter("Tex")
      expect(page).to have_selector('[role="option"]')
      find('[role="option"]', text: "Texas Rangers").click
      expect(find("#player_team_id", visible: false).value).to eq teams[1].id.to_s
    end

    it "clears the current selection with making the search box empty" do
      visit edit_path(model_name: "player", id: player.id)
      # Emulate the input event a real backspace-to-empty fires (Cuprite's set('')
      # clears via a direct value assignment that dispatches no input event).
      page.execute_script(<<~JS)
        const el = document.querySelector('input.ra-filtering-select-input');
        el.value = '';
        el.dispatchEvent(new Event('input', { bubbles: true }));
      JS
      expect(find("#player_team_id", visible: false).value).to be_empty
    end

    it "clears the current selection with selecting the clear option" do
      visit edit_path(model_name: "player", id: player.id)
      within(".filtering-select") { find(".dropdown-toggle").click }
      find('[role="option"]', text: /Clear/).click
      expect(find("#player_team_id", visible: false).value).to be_empty
    end

    context "when the field is required" do
      before do
        RailsAdminNext.config Player do
          field(:team) { required true }
        end
        visit edit_path(model_name: "player", id: player.id)
      end

      it "does not show the clear option" do
        within(".filtering-select") { find(".dropdown-toggle").click }
        expect(page).to have_selector('[role="option"]')
        expect(page).not_to have_css('[role="option"]', text: /Clear/)
      end
    end
  end

  it "prevents duplication when using browser back and forward" do
    player
    visit index_path(model_name: "player")
    find(%([href$="/admin/player/#{player.id}/edit"])).click
    is_expected.to have_content "Edit Player"
    page.go_back
    is_expected.to have_content "List of Players"
    page.go_forward
    is_expected.to have_content "Edit Player"
    expect(all(:css, "input.ra-filtering-select-input").count).to eq 1
  end

  it "does not lose options on browser back" do
    visit edit_path(model_name: "player", id: player.id)
    find(".team_field .dropdown-toggle").click
    find('[role="option"]', text: /Clear/).click
    click_link "Show"
    is_expected.to have_content "Details for Player"
    page.go_back
    filter("Los", scope: ".team_field")
    expect(page).to have_selector('[role="option"]', text: "Los Angeles Dodgers")
  end

  context "when using remote requests" do
    before do
      RailsAdminNext.config Player do
        field :team do
          associated_collection_cache_all false
        end
      end
      visit new_path(model_name: "player")
    end

    # Each remote search is a full server round-trip; under a loaded CI runner the
    # debounce + request + render chain can exceed Capybara's 2s default wait, so
    # anchor on the expected option text with a longer wait before asserting the
    # settled count.
    it "supports filtering" do
      filter("ge")
      expect(page).to have_selector('[role="option"]', text: "Texas Rangers", wait: 10)
      expect(page).to have_selector('[role="option"]', count: 2)
      expect(option_labels).to match_array ["Los Angeles Dodgers", "Texas Rangers"]
      teams[0].update name: "Cincinnati Reds"
      filter("Red")
      expect(page).to have_selector('[role="option"]', text: "Cincinnati Reds", wait: 10)
      expect(page).to have_selector('[role="option"]', count: 1)
      expect(option_labels).to eq ["Cincinnati Reds"]
    end

    it "matches on fields other than the label when searching remotely" do
      teams[0].update manager: "Roberts"
      filter("Roberts")
      expect(page).to have_selector('[role="option"]', text: "Los Angeles Dodgers", wait: 10)
      expect(page).to have_selector('[role="option"]', count: 1)
      expect(option_labels).to eq ["Los Angeles Dodgers"]
    end
  end

  describe "dynamic scoping" do
    let!(:players) { FactoryBot.create_list :player, 2, team: teams[1] }
    let!(:freelancer) { FactoryBot.create :player, team: nil }

    context "with single field" do
      before do
        player
        RailsAdminNext.config Draft do
          field :team
          field :player do
            dynamically_scope_by :team
          end
        end
        visit new_path(model_name: "draft")
      end

      it "changes selection candidates based on value of the specified field" do
        expect(all("#draft_player_id option", visible: false).map(&:value).filter(&:present?)).to be_empty
        filter("Tex", scope: '[data-input-for="draft_team_id"]')
        expect(page).to have_selector('[role="option"]')
        find('[role="option"]', text: "Texas Rangers").click
        within('[data-input-for="draft_player_id"].filtering-select') { find(".dropdown-toggle").click }
        expect(option_labels).to match_array players.map(&:name)
      end

      it "allows filtering by blank value" do
        within('[data-input-for="draft_player_id"].filtering-select') { find(".dropdown-toggle").click }
        expect(option_labels).to match_array [freelancer.name]
      end
    end

    context "with multiple fields" do
      before do
        player
        RailsAdminNext.config Draft do
          field :team
          field :player do
            dynamically_scope_by [:team, {round: :number}]
          end
          field :round
        end
        visit new_path(model_name: "draft", draft: {team_id: teams[1].id})
      end

      it "changes selection candidates based on value of the specified fields" do
        fill_in "draft[round]", with: players[1].number
        within('[data-input-for="draft_player_id"].filtering-select') { find(".dropdown-toggle").click }
        expect(option_labels).to match_array [players[1].name]
      end
    end
  end
end
