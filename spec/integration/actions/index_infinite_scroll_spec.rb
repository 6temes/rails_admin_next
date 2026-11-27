# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Index action under infinite scroll", type: :request do
  subject { page }

  def batch(page_number, **params)
    get index_path(model_name: "player", page: page_number, **params), headers: {"Turbo-Frame" => "list_batch_#{page_number}"}
    Capybara.string(Nokogiri::HTML5.fragment(response.body))
  end

  def batch_rows(body) = body.native.css("turbo-stream > template tr")

  # The list's links repeat the route's model_name in the query string, so compare
  # the path and the remaining query.
  def link_target(url)
    uri = URI(url)
    [uri.path, Rack::Utils.parse_nested_query(uri.query).except("model_name")]
  end

  def page_target(page_number) = [index_path(model_name: "player"), {"page" => page_number.to_s}]

  def count_queries(&)
    counts = []
    counter = ->(*, payload) { counts << payload[:sql] if payload[:sql].match?(/\bCOUNT\(/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    counts
  end

  before { RailsAdminNext.config.default_items_per_page = 20 }

  context "with 45 players" do
    before { FactoryBot.create_list(:player, 45) }

    it "shows the first batch with a lazy frame linking to page 2 and no pager" do
      visit index_path(model_name: "player")

      is_expected.to have_css("tbody#list_rows tr", count: 20)
      is_expected.to have_no_css("ul.pagination")
      frame = find("#sidescroll + turbo-frame#list_batch_2[loading='lazy']")
      expect(link_target(frame[:src])).to eq page_target(2)
      expect(link_target(frame.find("a")[:href])).to eq page_target(2)
    end

    it "answers a frame request for page 2 with a rows-only batch chaining to page 3" do
      body = batch(2)

      expect(response.body).not_to match(/<html|<head|<body/)
      expect(body).to have_no_css("#list")
      expect(body).to have_css("turbo-frame#list_batch_2", count: 1)
      expect(body).to have_css("turbo-frame#list_batch_2 > turbo-stream[action='append'][target='list_rows']")
      expect(batch_rows(body).size).to eq 20
      next_frame = body.find("turbo-frame#list_batch_2 turbo-frame#list_batch_3[loading='lazy']")
      expect(link_target(next_frame[:src])).to eq page_target(3)
    end

    it "ends the list on page 3 with 5 rows and no further frame" do
      body = batch(3)

      expect(batch_rows(body).size).to eq 5
      expect(body).to have_css("turbo-frame#list_batch_3 .list-end", text: "End of list")
      expect(body).to have_css("turbo-frame", count: 1)
    end

    it "renders the full page at a batch when the frame header is absent" do
      visit index_path(model_name: "player", page: 2)

      expected = Player.order(id: :desc).offset(20).limit(20).map(&:id)
      expect(all("tbody#list_rows tr").map { it[:id] }).to eq(expected.map { "row_player_#{it}" })
      expect(link_target(find("turbo-frame#list_batch_3 a")[:href])).to eq page_target(3)
    end

    it "shows the delimited total count once, above the table" do
      visit index_path(model_name: "player")

      is_expected.to have_css("div.total-count", count: 1, text: "45 players")
      is_expected.to have_css("div.total-count ~ form#bulk_form #sidescroll")
    end

    it "renders no Show all link" do
      visit index_path(model_name: "player")

      is_expected.to have_no_link("Show all")
      is_expected.to have_no_css("a[href*='all=true']")
    end

    it "lists every row once with the count and no frame when all=true" do
      visit index_path(model_name: "player", all: true)

      is_expected.to have_css("tbody#list_rows tr", count: 45)
      is_expected.to have_css("div.total-count", count: 1, text: "45 players")
      is_expected.to have_no_css("turbo-frame")
    end

    it "runs no COUNT query for a batch" do
      expect(count_queries { batch(2) }).to be_empty
    end

    it "holds no inline script or style in a batch" do
      batch(2)

      expect(response.body).not_to match(/<script|<style|style=/i)
    end

    it "gives every row a DOM id" do
      visit index_path(model_name: "player")

      expect(all("tbody#list_rows tr").map { it[:id] }).to all(match(/\Arow_player_\d+\z/))
    end
  end

  it "ends with no rows, the end marker and no empty-list row when the last full page was the end" do
    FactoryBot.create_list(:player, 40)
    body = batch(3)

    expect(batch_rows(body)).to be_empty
    expect(body).to have_css(".list-end")
    expect(body).to have_no_content("No records found")
    expect(body).to have_css("turbo-frame", count: 1)
  end

  it "renders no frame and no end marker for a list that fits one batch" do
    FactoryBot.create_list(:player, 2)
    visit index_path(model_name: "player")

    is_expected.to have_no_css("turbo-frame")
    is_expected.to have_no_css(".list-end")
  end

  it "carries the query, filter, scope tab, sort and per into the next batch URL" do
    RailsAdminNext.config(Player) { list { scopes [nil, :retired] } }
    FactoryBot.create_list(:player, 3, retired: true, name: "ABBA")
    params = {query: "ABBA", f: {name: {"1" => {o: "is", v: "ABBA"}}}, scope: "retired", sort: "name", sort_reverse: "true", per: 2}
    visit index_path(model_name: "player", **params)

    _, query = link_target(find("turbo-frame#list_batch_2")[:src])
    expect(query).to eq({"page" => "2"}.merge(params.deep_stringify_keys.transform_values { it.is_a?(Hash) ? it : it.to_s }))
  end

  it "formats a large count with a thousands delimiter" do
    FactoryBot.create(:player)
    allow_any_instance_of(RailsAdminNext::PaginatedCollection).to receive(:total_count).and_return(104_327)
    visit index_path(model_name: "player")

    is_expected.to have_css("div.total-count", text: "104,327 players")
  end

  context "with limited_pagination" do
    before do
      RailsAdminNext.config(Player) { list { limited_pagination true } }
      FactoryBot.create_list(:player, 45)
    end

    it "shows no count and runs no COUNT query on the page or a batch" do
      queries = count_queries do
        visit index_path(model_name: "player")
        batch(2)
      end

      expect(queries).to be_empty
      visit index_path(model_name: "player")
      is_expected.to have_no_css("div.total-count")
      is_expected.to have_css("turbo-frame#list_batch_2")
    end
  end

  context "with the numbered pager" do
    before do
      RailsAdminNext.config(Player) { list { pagination :numbered } }
      FactoryBot.create_list(:player, 45)
    end

    it "renders the pager, Show all and the count after the table, with no frame" do
      visit index_path(model_name: "player")

      is_expected.to have_css("#sidescroll ~ .row ul.pagination")
      is_expected.to have_link("Show all")
      is_expected.to have_css("#sidescroll ~ div.total-count", count: 1, text: "45 players")
      is_expected.to have_no_css("turbo-frame")
    end
  end

  it "gives rows of a composite-key model a DOM id", composite_primary_keys: true do
    FactoryBot.create_list(:fanship, 2)
    visit index_path(model_name: "fanship")

    expect(all("tbody#list_rows tr").map { it[:id] }).to all(match(/\Arow_fanship_\d+_\d+\z/))
    expect(all("tbody#list_rows tr").size).to eq 2
  end
end
