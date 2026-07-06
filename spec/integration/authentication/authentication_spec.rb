# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAdminNext Authentication", type: :request do
  subject { page }
  let!(:user) { FactoryBot.create :user }

  before do
    RailsAdminNext.config do |config|
      config.authenticate_with do
        warden.authenticate! scope: :user
      end
      config.current_user_method(&:current_user)
    end
  end

  it "allows access when logged in" do
    login_as user
    visit dashboard_path
    is_expected.to have_css "body.rails_admin"
  end

  it "blocks access when not logged in" do
    visit dashboard_path
    expect(page.status_code).to eq(401)
  end
end
