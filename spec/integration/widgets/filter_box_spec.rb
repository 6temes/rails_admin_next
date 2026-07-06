# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Filter box widget", type: :request, js: true do
  subject { page }

  it "adds filters" do
    RailsAdminNext.config Player do
      field :name
      field :position
    end
    visit index_path(model_name: "player")
    is_expected.to have_no_css("#filters_box .filter")
    click_button "Add filter"
    click_link "Name"
    within("#filters_box") do
      is_expected.to have_css(".filter", count: 1)
      is_expected.to have_css('.filter select[name^="f[name]"]')
    end
    click_button "Add filter"
    click_link "Position"
    within("#filters_box") do
      is_expected.to have_css(".filter", count: 2)
      is_expected.to have_css('.filter select[name^="f[position]"]')
    end
  end

  it "removes filters" do
    RailsAdminNext.config Player do
      field :name
      field :position
    end
    visit index_path(model_name: "player")
    is_expected.to have_no_css("#filters_box .filter")
    click_button "Add filter"
    click_link "Name"
    click_button "Add filter"
    click_link "Position"
    within("#filters_box") do
      is_expected.to have_css(".filter", count: 2)
      click_button "Name"
      is_expected.to have_no_css('.filter select[name^="f[name]"]')
      click_button "Position"
      is_expected.to have_no_css(".filter")
    end
  end

  it "shows the filters divider only while filters are present" do
    RailsAdminNext.config Player do
      field :name
    end
    visit index_path(model_name: "player")
    is_expected.to have_no_css("hr.filters_box")
    click_button "Add filter"
    click_link "Name"
    is_expected.to have_css("hr.filters_box")
    within("#filters_box") { click_button "Name" }
    is_expected.to have_no_css("hr.filters_box")
  end

  it "leaves the divider and fieldset visibility consistent after a filter reset" do
    RailsAdminNext.config Player do
      field :name
    end
    visit index_path(model_name: "player", f: {name: {"1" => {v: "a"}}})
    is_expected.to have_css("#filters_box .filter", count: 1)
    is_expected.to have_css("hr.filters_box")
    find_button("Reset filters").click
    is_expected.to have_no_css("#filters_box .filter")
    is_expected.to have_no_css("hr.filters_box")
  end

  it "hides redundant filter options for required fields" do
    RailsAdminNext.config Player do
      list do
        field :name do
          required true
        end
        field :team
      end
    end

    visit index_path(model_name: "player", f: {name: {"1" => {v: ""}}, team: {"2" => {v: ""}}})

    within(:select, name: "f[name][1][o]") do
      expect(page.all("option").map(&:value)).to_not include("_present", "_blank")
    end

    within(:select, name: "f[team][2][o]") do
      expect(page.all("option").map(&:value)).to include("_present", "_blank")
    end
  end

  it "supports limiting filter operators" do
    RailsAdminNext.config Player do
      list do
        field :name do
          filter_operators %w[is starts_with _present]
        end
      end
    end

    visit index_path(model_name: "player")
    is_expected.to have_no_css("#filters_box .filter")
    click_button "Add filter"
    click_link "Name"

    within(:select, name: /f\[name\]\[\d+\]\[o\]/) do
      expect(page.all("option").map(&:value)).to eq %w[is starts_with _present]
    end
  end

  it "keeps the value input visible when filter_operators is empty" do
    RailsAdminNext.config Player do
      list do
        field :name do
          filter_operators []
        end
      end
    end

    visit index_path(model_name: "player")
    click_button "Add filter"
    click_link "Name"

    within("#filters_box .filter") do
      expect(page).to have_no_css("select")
      expect(find('input[name$="[v]"]')).to be_visible
    end
  end

  it "does not cause duplication when using browser back" do
    RailsAdminNext.config Player do
      field :name
    end

    visit index_path(model_name: "player", f: {name: {"1" => {v: "a"}}})
    find(%([href$="/admin/player/export"])).click
    is_expected.to have_content "Export Players"
    page.go_back
    is_expected.to have_content "List of Players"
    expect(all(:css, "#filters_box div.filter").count).to eq 1
  end

  describe "for string field" do
    before do
      RailsAdminNext.config FieldTest do
        field :string_field
      end
    end

    it "shows the value input by default and hides it for presence operators" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "String field"
      within("#filters_box .filter") do
        expect(find('input[name$="[v]"]')).to be_visible
        find('select[name$="[o]"] option[value=_present]').select_option
        expect(page).to have_no_css('input[name$="[v]"]')
        find('select[name$="[o]"] option[value=_blank]').select_option
        expect(page).to have_no_css('input[name$="[v]"]')
        find('select[name$="[o]"] option[value=like]').select_option
        expect(find('input[name$="[v]"]')).to be_visible
      end
    end
  end

  describe "for boolean field" do
    before do
      RailsAdminNext.config FieldTest do
        field :boolean_field
      end
    end

    it "is filterable with true and false" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "Boolean field"
      within("#filters_box .filter") do
        expect(page.all("option").map(&:value)).to include("true", "false")
        # The select is the value control itself; there is no extra fieldset to reveal.
        expect(find('select[name$="[v]"]')).to be_visible
        expect(page).to have_no_css(".additional-fieldset", visible: :all)
      end
    end
  end

  describe "for integer field" do
    before do
      RailsAdminNext.config FieldTest do
        field :integer_field
      end
    end

    it "shows the single bound by default and reveals both bounds for between" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "Integer field"
      within("#filters_box .filter") do
        expect(page).to have_css('input.additional-fieldset.default[name$="[v][]"]', count: 1)
        expect(page).to have_no_css("input.additional-fieldset.between")
        find('select[name$="[o]"] option[value=between]').select_option
        expect(page).to have_css('input.additional-fieldset.between[name$="[v][]"]', count: 2)
        expect(page).to have_no_css("input.additional-fieldset.default")
      end
    end
  end

  describe "for date field" do
    before do
      RailsAdminNext.config FieldTest do
        field :date_field
      end
    end

    it "renders a native date input that round-trips an ISO date" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "Date field"
      input = find('[name^="f[date_field]"][name$="[v][]"]', match: :first)
      expect(input[:type]).to eq "date"
      expect(input.value).to be_blank
      input.set("2015-10-08")
      expect(input.value).to eq "2015-10-08"
    end

    it "switches the visible bounds with the operator" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "Date field"
      within("#filters_box .filter") do
        expect(page).to have_css(".additional-fieldset.default input[type=date]", count: 1)
        expect(page).to have_no_css(".additional-fieldset.between input[type=date]")
        find('select[name$="[o]"] option[value=between]').select_option
        expect(page).to have_css(".additional-fieldset.between input[type=date]", count: 2)
        expect(page).to have_no_css(".additional-fieldset.default input[type=date]")
        find('select[name$="[o]"] option[value=today]').select_option
        expect(page).to have_no_css(".additional-fieldset input[type=date]")
      end
    end
  end

  describe "for datetime field" do
    before do
      RailsAdminNext.config FieldTest do
        field :datetime_field
      end
    end

    it "renders a native datetime-local input that round-trips an ISO datetime" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "Datetime field"
      input = find('[name^="f[datetime_field]"][name$="[v][]"]', match: :first)
      expect(input[:type]).to eq "datetime-local"
      expect(input.value).to be_blank
      input.set("2015-10-08T14:30:15")
      expect(input.value).to eq "2015-10-08T14:30:15"
    end
  end

  describe "for enum field" do
    before do
      RailsAdminNext.config Team do
        field :color, :enum
      end
    end

    it "supports multiple selection mode" do
      visit index_path(model_name: "team")
      click_button "Add filter"
      click_link "Color"
      expect(all("#filters_box option").map(&:text)).to include "white", "black", "red", "green", "blu<e>é"
      find('.filter .switch-select svg[data-icon="new"]').click
      expect(find("#filters_box select")["multiple"]).to be true
      expect(find("#filters_box select")["name"]).to match(/\[\]$/)
      # Multiple mode lists enum values only: the operator entries hide via
      # attributes (WebKit ignores display styling on <option>).
      expect(page).to have_css("#filters_box option[value=_discard][hidden][disabled]", visible: :all)
      expect(page).to have_css("#filters_box option[value=_present][hidden][disabled]", visible: :all)
      find('.filter .switch-select svg[data-icon="minus"]').click
      is_expected.to have_no_css("#filters_box select[multiple]")
      expect(find("#filters_box select")["name"]).not_to match(/\[\]$/)
      expect(page).to have_no_css("#filters_box option[value=_discard][hidden]", visible: :all)
      expect(page).to have_no_css("#filters_box option[value=_discard][disabled]", visible: :all)
    end

    context "with the filter pre-populated" do
      it "does not break" do
        visit index_path(model_name: "team", f: {color: {"1" => {v: "red"}}})
        is_expected.to have_css('.filter select[name^="f[color]"]')
        expect(find('.filter select[name^="f[color]"]').value).to eq "red"
        expect(all("#filters_box option").map(&:text)).to include "white", "black", "red", "green", "blu<e>é"
      end
    end

    context "with the filter pre-populated with multiple values" do
      it "renders in multiple mode with the operator entries hidden" do
        visit index_path(model_name: "team", f: {color: {"1" => {v: %w[red black]}}})
        expect(find('.filter select[name^="f[color]"]')["multiple"]).to be true
        expect(find('.filter select[name^="f[color]"]').value).to include("red", "black")
        expect(page).to have_css("#filters_box option[value=_discard][hidden][disabled]", visible: :all)
      end
    end
  end

  describe "for time field", active_record: true do
    before do
      RailsAdminNext.config FieldTest do
        field :time_field
      end
    end

    it "renders a native time input that round-trips a time value" do
      visit index_path(model_name: "field_test")
      click_button "Add filter"
      click_link "Time field"
      input = find('[name^="f[time_field]"][name$="[v][]"]', match: :first)
      expect(input[:type]).to eq "time"
      expect(input.value).to be_blank
      input.set("2000-01-01T14:00:00")
      expect(input.value).to eq "14:00:00"
    end
  end

  describe "for has_one association field" do
    before do
      RailsAdminNext.config Player do
        field :draft do
          searchable :college
        end
      end
    end

    it "is filterable" do
      visit index_path(model_name: "player")
      click_button "Add filter"
      click_link "Draft"
      expect(page).to have_css '[name^="f[draft]"][name$="[o]"]'
      expect(page).to have_css '[name^="f[draft]"][name$="[v]"]'
    end
  end
end
