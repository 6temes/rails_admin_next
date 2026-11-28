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

  context "with a model PaperTrail does not version" do
    let!(:team) { FactoryBot.create :team }

    it "lists no history", :aggregate_failures do
      visit history_index_path(model_name: "team")
      expect(page.status_code).to eq 200
      expect(all("table#history tbody tr").count).to eq 0
    end

    it "renders no History link", :aggregate_failures do
      visit index_path(model_name: "team")
      is_expected.not_to have_css("li.history_index_collection_link")
      visit index_path(model_name: "paper_trail_test")
      is_expected.to have_css("li.history_index_collection_link")
    end

    it "renders the History link for an auditing adapter that does not define auditable?" do
      adapter = Class.new { def listing_for_model(*) = [] }
      RailsAdminNext.config { |config| config.audit_with { @auditing_adapter = adapter.new } }

      visit index_path(model_name: "team")
      is_expected.to have_css("li.history_index_collection_link")
    end
  end

  describe "under infinite scroll" do
    def batch(page_number, **params)
      get history_index_path(model_name: "paper_trail_test", page: page_number, **params), headers: {"Turbo-Frame" => "history_batch_#{page_number}"}
      Capybara.string(Nokogiri::HTML5.fragment(response.body))
    end

    def batch_rows(body) = body.native.css("turbo-stream > template tr")

    def link_target(url)
      uri = URI(url)
      [uri.path, Rack::Utils.parse_nested_query(uri.query).except("model_name")]
    end

    def count_queries(&)
      counts = []
      counter = ->(*, payload) { counts << payload[:sql] if payload[:sql].match?(/\bCOUNT\(/i) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
      counts
    end

    it "shows a lazy frame for page 2 after the first 20 versions, with no pager", :aggregate_failures do
      visit history_index_path(model_name: "paper_trail_test")

      is_expected.to have_css("tbody#history_rows tr", count: 20)
      is_expected.to have_no_css("ul.pagination")
      frame = find("table#history + turbo-frame#history_batch_2[loading='lazy']")
      expect(link_target(frame[:src])).to eq [history_index_path(model_name: "paper_trail_test"), {"page" => "2"}]
      expect(link_target(frame.find("a")[:href])).to eq [history_index_path(model_name: "paper_trail_test"), {"page" => "2"}]
    end

    it "answers a frame request for page 2 with the remaining 11 versions and the end marker", :aggregate_failures do
      body = batch(2)

      expect(response.body).not_to match(/<html|<head|<body/)
      expect(body).to have_css("turbo-frame#history_batch_2 > turbo-stream[action='append'][target='history_rows']")
      expect(batch_rows(body).size).to eq 11
      expect(batch_rows(body).map { it[:id] }).to eq PaperTrail::Version.order(id: :desc).offset(20).map { "history_row_#{it.id}" }
      expect(body).to have_css("turbo-frame#history_batch_2 .list-end", text: "End of list")
      expect(body).to have_css("turbo-frame", count: 1)
    end

    it "keeps a routing option in the query string out of the next batch's path", :aggregate_failures do
      RailsAdminNext.config.default_items_per_page = 10
      body = batch(2, "script_name" => "//evil.example")

      src = body.find("turbo-frame#history_batch_2 turbo-frame#history_batch_3")[:src]
      expect(src).to start_with(history_index_path(model_name: "paper_trail_test"))
      expect(link_target(src)).to eq [history_index_path(model_name: "paper_trail_test"), {"page" => "3", "script_name" => "//evil.example"}]
    end

    it "carries the query into the next-batch URL" do
      visit history_index_path(model_name: "paper_trail_test", query: "update")

      expect(link_target(find("turbo-frame#history_batch_2")[:src])).to eq [history_index_path(model_name: "paper_trail_test"), {"page" => "2", "query" => "update"}]
    end

    it "lists every version once with no frame when all=true", :aggregate_failures do
      visit history_index_path(model_name: "paper_trail_test", all: true)

      is_expected.to have_css("tbody#history_rows tr", count: 31)
      is_expected.to have_no_css("turbo-frame")
    end

    it "runs no COUNT query on the page or a batch" do
      queries = count_queries do
        visit history_index_path(model_name: "paper_trail_test")
        batch(2)
      end

      expect(queries).to be_empty
    end

    it "returns each version exactly once across the batches of a sort shared by every version", :aggregate_failures do
      visit history_index_path(model_name: "paper_trail_test", sort: "item")
      ids = all("tbody#history_rows tr").map { it[:id] }
      ids += batch_rows(batch(2, sort: "item")).map { it[:id] }

      expect(ids.size).to eq 31
      expect(ids).to match_array(PaperTrail::Version.pluck(:id).map { "history_row_#{it}" })
    end

    it "renders a 200 page with no frame for a custom adapter returning an empty array", :aggregate_failures do
      adapter = Class.new { def listing_for_model(*) = [] }
      RailsAdminNext.config { |config| config.audit_with { @auditing_adapter = adapter.new } }

      visit history_index_path(model_name: "paper_trail_test")
      expect(page.status_code).to eq 200
      is_expected.to have_no_css("turbo-frame")
    end

    it "renders the numbered pager for a custom adapter whose listing has current_page but not full_page?", :aggregate_failures do
      listing = Class.new(SimpleDelegator) do
        def current_page = 1

        def total_pages = 2

        def total_count = 2

        def first_page? = true

        def last_page? = false
      end
      adapter = Class.new { define_method(:listing_for_model) { |*| listing.new([]) } }
      RailsAdminNext.config { |config| config.audit_with { @auditing_adapter = adapter.new } }

      visit history_index_path(model_name: "paper_trail_test")
      is_expected.to have_css("ul.pagination")
      is_expected.to have_no_css("turbo-frame")
    end

    describe "in the browser", js: true do
      it "brings the 21st version's row in once scrolled to the bottom" do
        visit history_index_path(model_name: "paper_trail_test")
        is_expected.to have_css("tbody#history_rows tr", minimum: 20)

        page.document.synchronize(10) do
          page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")
          raise Capybara::ExpectationNotMet, "never found the end of the list" unless page.has_css?(".list-end", wait: 0)
        end
        is_expected.to have_css("tbody#history_rows tr", count: 31)
        is_expected.to have_css("tbody#history_rows tr:nth-child(21)#history_row_#{PaperTrail::Version.order(id: :desc).offset(20).first.id}")
      end
    end
  end

  it "supports sorting", js: true do
    visit history_index_path(model_name: "paper_trail_test")
    find("th.header", text: "Item").click
    is_expected.to have_css("th.item.headerSortDown")
  end
end
