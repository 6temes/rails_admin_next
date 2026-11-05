# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HistoryShow action", type: :request, active_record: true do
  let(:user) { FactoryBot.create :user }
  let(:paper_trail_test) { FactoryBot.create :paper_trail_test }
  before(:each) do
    RailsAdminNext.config do |config|
      config.audit_with :paper_trail, "User", "PaperTrail::Version"
    end

    PaperTrail::Version.delete_all
    with_versioning do
      PaperTrail.request.whodunnit = user.id
      30.times do |i|
        paper_trail_test.update!(name: "updated name #{i}")
      end
    end
  end

  it "shows the history" do
    visit history_show_path(model_name: "paper_trail_test", id: paper_trail_test.id)
    expect(all("table#history tbody tr").count).to eq(20)
  end

  it "supports pagination" do
    visit history_show_path(model_name: "paper_trail_test", id: paper_trail_test.id, page: 2)
    expect(all("table#history tbody tr").count).to eq(11)
  end

  context "with a model PaperTrail does not version" do
    let(:team) { FactoryBot.create :team }

    it "lists no history", :aggregate_failures do
      visit history_show_path(model_name: "team", id: team.id)
      expect(page.status_code).to eq 200
      expect(all("table#history tbody tr").count).to eq 0
    end

    it "renders no History link", :aggregate_failures do
      visit show_path(model_name: "team", id: team.id)
      expect(page).not_to have_css("li.history_show_member_link")
      visit show_path(model_name: "paper_trail_test", id: paper_trail_test.id)
      expect(page).to have_css("li.history_show_member_link")
    end
  end
end
