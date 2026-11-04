# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HistoryIndex action", type: :request, active_record: true do
  subject { page }

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
    visit history_index_path(model_name: "paper_trail_test")
    is_expected.to have_css(%([href="/admin/paper_trail_test/#{paper_trail_test.id}"]), count: 20)
  end

  it "supports pagination" do
    visit history_index_path(model_name: "paper_trail_test", page: 2)
    is_expected.to have_css(%([href="/admin/paper_trail_test/#{paper_trail_test.id}"]), count: 11)
  end

  it "calls an auditing adapter without scope keywords when no authorization adapter is configured", :aggregate_failures do
    adapter = Class.new do
      def latest(_count) = []

      def listing_for_model(_model, _query, _sort, _sort_reverse, _all, _page) = []
    end
    RailsAdminNext.config { |config| config.audit_with { @auditing_adapter = adapter.new } }

    visit dashboard_path
    expect(page.status_code).to eq 200
    visit history_index_path(model_name: "paper_trail_test")
    expect(page.status_code).to eq 200
  end

  it "supports sorting", js: true do
    visit history_index_path(model_name: "paper_trail_test")
    find("th.header", text: "Item").click
    is_expected.to have_css("th.item.headerSortDown")
  end
end
