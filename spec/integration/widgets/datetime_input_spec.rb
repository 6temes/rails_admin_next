# frozen_string_literal: true

require "spec_helper"

# The edit widget for date/datetime/time fields is a native HTML5 input
# (<input type="date|datetime-local|time">). The picker UI and its configurable
# display format / localization are the browser's; only ISO values cross the wire.
RSpec.describe "Datetime native input widget", type: :request, js: true do
  subject { page }

  before do
    RailsAdminNext.config FieldTest do
      edit do
        field :datetime_field
      end
    end
  end

  it "renders a native datetime-local input" do
    visit new_path(model_name: "field_test")
    expect(find('[name="field_test[datetime_field]"]')[:type]).to eq "datetime-local"
  end

  it "is initially blank" do
    visit new_path(model_name: "field_test")
    expect(find('[name="field_test[datetime_field]"]').value).to be_blank
  end

  # step: 1 keeps second precision; the browser only serializes seconds in `.value` when non-zero.
  it "round-trips an ISO value (including seconds) entered into the input" do
    visit new_path(model_name: "field_test")
    find('[name="field_test[datetime_field]"]').set("2015-10-08T14:30:15")
    expect(find('[name="field_test[datetime_field]"]').value).to eq "2015-10-08T14:30:15"
    click_button "Save"
    expect(FieldTest.first.datetime_field).to eq DateTime.new(2015, 10, 8, 14, 30, 15)
  end

  it "shows the persisted value in the input on edit" do
    field_test = FactoryBot.create(:field_test, datetime_field: DateTime.new(2021, 1, 2, 3, 45, 30))
    visit edit_path(model_name: "field_test", id: field_test.id)
    expect(find('[name="field_test[datetime_field]"]').value).to eq "2021-01-02T03:45:30"
  end
end
