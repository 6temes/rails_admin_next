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

  describe "under infinite scroll" do
    def show_path = history_show_path(model_name: "paper_trail_test", id: paper_trail_test.id)

    def batch(page_number)
      get history_show_path(model_name: "paper_trail_test", id: paper_trail_test.id, page: page_number), headers: {"Turbo-Frame" => "history_batch_#{page_number}"}
      Capybara.string(Nokogiri::HTML5.fragment(response.body))
    end

    def batch_rows(body) = body.native.css("turbo-stream > template tr")

    def link_target(url)
      uri = URI(url)
      [uri.path, Rack::Utils.parse_nested_query(uri.query).except("model_name", "id")]
    end

    it "shows a lazy frame for page 2 that keeps the record id", :aggregate_failures do
      visit show_path

      expect(all("tbody#history_rows tr").count).to eq 20
      expect(page).to have_no_css("ul.pagination")
      expect(link_target(find("table#history + turbo-frame#history_batch_2[loading='lazy']")[:src])).to eq [show_path, {"page" => "2"}]
    end

    it "answers a frame request for page 2 with the remaining 11 versions and the end marker", :aggregate_failures do
      body = batch(2)

      expect(body).to have_css("turbo-frame#history_batch_2 > turbo-stream[action='append'][target='history_rows']")
      expect(batch_rows(body).size).to eq 11
      expect(body).to have_css("turbo-frame#history_batch_2 .list-end")
      expect(body).to have_css("turbo-frame", count: 1)
    end

    it "chains a batch to the next one on the record's own history" do
      RailsAdminNext.config.default_items_per_page = 10
      body = batch(2)

      expect(link_target(body.find("turbo-frame#history_batch_2 turbo-frame#history_batch_3")[:src])).to eq [show_path, {"page" => "3"}]
    end

    it "keeps the numbered pager for a model set to it", :aggregate_failures do
      RailsAdminNext.config(PaperTrailTest) { list { pagination :numbered } }
      visit show_path

      expect(page).to have_css("table#history ~ nav ul.pagination")
      expect(page).to have_no_css("turbo-frame")
    end
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
