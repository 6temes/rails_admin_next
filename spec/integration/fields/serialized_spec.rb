# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Serialized field", type: :request do
  subject { page }

  context "with serialized objects" do
    before do
      RailsAdminNext.config do |c|
        c.model User do
          configure :roles, :serialized
        end
      end

      @user = FactoryBot.create :user

      visit edit_path(model_name: "user", id: @user.id)

      fill_in "user[roles]", with: %(['admin', 'user'])
      click_button "Save" # first(:button, "Save").click

      @user.reload
    end

    it "saves the serialized data" do
      expect(@user.roles).to eq(%w[admin user])
    end
  end

  context "with a store attribute" do
    let(:field_test) { FieldTest.create!(store_field: {"color" => "red"}) }

    it "saves the form unchanged" do
      visit edit_path(model_name: "field_test", id: field_test.id)
      click_button "Save"

      expect(field_test.reload.store_field).to eq("color" => "red")
    end

    it "saves an edited value" do
      visit edit_path(model_name: "field_test", id: field_test.id)
      fill_in "field_test[store_field]", with: "color: blue\nsize: :large\n"
      click_button "Save"

      expect(field_test.reload.store_field).to eq("color" => "blue", "size" => :large)
    end
  end
end
