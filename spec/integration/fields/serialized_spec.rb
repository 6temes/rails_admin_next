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
end
