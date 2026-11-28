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

    it "keeps a routing option in the query string out of the next batch's path" do
      body = batch(2, "script_name" => "//evil.example")

      src = body.find("turbo-frame#list_batch_2 turbo-frame#list_batch_3")[:src]
      expect(link_target(src)).to eq [index_path(model_name: "player"), {"page" => "3", "script_name" => "//evil.example"}]
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

  it "gives rows of a composite-key model a DOM id", composite_primary_keys: true do
    FactoryBot.create_list(:fanship, 2)
    visit index_path(model_name: "fanship")

    expect(all("tbody#list_rows tr").map { it[:id] }).to all(match(/\Arow_fanship_\d+_\d+\z/))
    expect(all("tbody#list_rows tr").size).to eq 2
  end

  describe "in the browser", js: true do
    before do
      @index_requests = []
      @subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
        @index_requests << payload[:params]["page"] if payload[:controller] == "RailsAdminNext::MainController" && payload[:action] == "index"
      end
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@subscriber)
      page.current_window.resize_to(1024, 768)
    end

    # At 1024x768 the first pending frame starts below the fold but within the
    # one-viewport look-ahead, so batch 2 loads on its own. This height puts it
    # beyond the look-ahead, for scenarios that need the unloaded state.
    def short_window = page.current_window.resize_to(1024, 400)

    def rows = all("tbody#list_rows tr")

    def row_ids = rows.map { it[:id] }

    def scroll_to_bottom = page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

    def scroll_until(selector, **)
      page.document.synchronize(10) do
        scroll_to_bottom
        raise Capybara::ExpectationNotMet, "never found #{selector}" unless page.has_css?(selector, wait: 0, **)
      end
    end

    def scroll_until_end = scroll_until(".list-end")

    # Two animation frames: long enough for an intersection observer to report a
    # scroll and for any load it starts to issue its fetch.
    def settle = page.evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")

    def delay_fetch(matching, by:)
      page.execute_script(<<~JS)
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          if (String(args[0]).includes(#{matching.to_json})) {
            return new Promise((resolve, reject) => {
              setTimeout(() => originalFetch.apply(window, args).then(resolve, reject), #{Integer(by)});
            });
          }
          return originalFetch.apply(window, args);
        };
      JS
    end

    # Rejects matching fetches as a network failure would, counting attempts,
    # until window.liftFetchFailure is set. Turbo rethrows a failed frame fetch
    # from a promise nobody awaits, so the simulated failure is marked handled
    # to keep it from failing the example as a JS error.
    def fail_fetch(matching)
      page.execute_script(<<~JS)
        const originalFetch = window.fetch;
        const failure = new TypeError("Failed to fetch");
        window.failedFetches = 0;
        window.addEventListener("unhandledrejection", (event) => {
          if (event.reason === failure) event.preventDefault();
        });
        window.fetch = function(...args) {
          if (!window.liftFetchFailure && String(args[0]).includes(#{matching.to_json})) {
            window.failedFetches += 1;
            return Promise.reject(failure);
          }
          return originalFetch.apply(window, args);
        };
      JS
    end

    it "loads the batches up to the end of 45 players, then requests nothing more" do
      FactoryBot.create_list(:player, 45)
      visit index_path(model_name: "player")

      scroll_until_end
      is_expected.to have_css("tbody#list_rows tr", count: 45)
      expect(@index_requests).to eq [nil, "2", "3"]

      scroll_to_bottom
      settle
      expect(@index_requests).to eq [nil, "2", "3"]
    end

    it "brings the oldest of 200 players in only once scrolled to the end" do
      players = FactoryBot.create_list(:player, 200)
      oldest = "#row_player_#{players.first.id}"
      visit index_path(model_name: "player")

      is_expected.to have_css("tbody#list_rows tr", minimum: 20)
      is_expected.to have_no_css(oldest)
      scroll_until_end
      is_expected.to have_css(oldest)
    end

    it "loads the next batch without scrolling when the pending frame is less than one viewport below the fold" do
      FactoryBot.create_list(:player, 45)
      visit index_path(model_name: "player")

      is_expected.to have_css("tbody#list_rows tr", minimum: 40)
      expect(page.evaluate_script("window.scrollY")).to eq 0
      expect(page.evaluate_script("document.querySelectorAll('#list_rows tr')[19].getBoundingClientRect().bottom > window.innerHeight")).to be true
    end

    it "shows the loading text while a batch is pending, and drops it once the rows land" do
      short_window
      FactoryBot.create_list(:player, 45)
      visit index_path(model_name: "player")
      is_expected.to have_css("tbody#list_rows tr", count: 20)
      is_expected.to have_no_css(".list-batch-loading", visible: :visible)

      delay_fetch("page=2", by: 1000)
      scroll_to_bottom
      is_expected.to have_css("#list_batch_2 .list-batch-loading", text: "Loading...", visible: :visible)
      is_expected.to have_css("tbody#list_rows tr:nth-child(21)")
      is_expected.to have_no_css(".list-batch-loading", visible: :visible)
    end

    it "pauses on a failed batch until Retry, which loads it without the page-load badge" do
      short_window
      FactoryBot.create_list(:player, 45)
      visit index_path(model_name: "player")
      is_expected.to have_css("tbody#list_rows tr", count: 20)

      fail_fetch("page=2")
      scroll_to_bottom
      is_expected.to have_css("#list_batch_2 .list-batch-error", text: "The next rows could not be loaded.", visible: :visible)
      is_expected.to have_link("Retry")

      scroll_to_bottom
      settle
      expect(page.evaluate_script("window.failedFetches")).to eq 1
      expect(rows.size).to eq 20

      page.execute_script("window.liftFetchFailure = true")
      click_link "Retry"
      is_expected.to have_css("tbody#list_rows tr:nth-child(21)")
      is_expected.to have_no_css(".list-batch-error", visible: :visible)
      is_expected.to have_no_css("#loading", visible: :visible)
    end

    context "when the server raises on a batch" do
      around do |example|
        Capybara.raise_server_errors = false
        example.run
      ensure
        Capybara.raise_server_errors = true
      end

      it "shows the error state instead of Content missing, with no JS error" do
        short_window
        FactoryBot.create_list(:player, 45)
        allow_any_instance_of(RailsAdminNext::MainController).to receive(:list_entries).and_wrap_original do |original, *args|
          raise "batch failed" if original.receiver.params[:page] == "2"

          original.call(*args)
        end
        visit index_path(model_name: "player")
        is_expected.to have_css("tbody#list_rows tr", count: 20)

        scroll_to_bottom
        is_expected.to have_css("#list_batch_2 .list-batch-error", text: "The next rows could not be loaded.", visible: :visible)
        is_expected.to have_link("Retry")
        is_expected.to have_no_content("Content missing")
      end
    end

    it "restores every loaded row and the scroll offset on Back without a list request, and starts over on refresh" do
      short_window
      FactoryBot.create_list(:player, 70)
      visit index_path(model_name: "player")
      scroll_until_end
      is_expected.to have_css("tbody#list_rows tr", count: 70)
      offset = 1500
      page.execute_script("window.scrollTo(0, #{offset})")
      settle
      expect(page.evaluate_script("window.scrollY")).to eq offset
      requests = @index_requests.dup

      # Clicked from script: a driver click first scrolls the link into view,
      # which would move the offset Back restores.
      player = Player.find(page.evaluate_script("[...document.querySelectorAll('#list_rows tr')].find((row) => row.getBoundingClientRect().top > 0).id").delete_prefix("row_player_"))
      page.execute_script("arguments[0].click()", find("#row_player_#{player.id} a[href$='/player/#{player.id}']"))
      is_expected.to have_no_css("tbody#list_rows")
      is_expected.to have_content(player.name)
      page.go_back

      is_expected.to have_css("tbody#list_rows tr", count: 70)
      page.document.synchronize do
        raise Capybara::ExpectationNotMet, "scroll offset not restored" unless page.evaluate_script("window.scrollY") == offset
      end
      expect(@index_requests).to eq requests

      # From the top: the browser restores a refreshed page's scroll offset,
      # which would let the look-ahead fetch the next batch straight away.
      page.execute_script("window.scrollTo(0, 0)")
      page.refresh
      is_expected.to have_css("tbody#list_rows tr", count: 20)
      expect(@index_requests.last).to be_nil
    end

    it "starts from the first batch again after a sort" do
      short_window
      FactoryBot.create_list(:player, 70)
      visit index_path(model_name: "player")
      scroll_until("tbody#list_rows tr", minimum: 60)

      find("th.name_field").click
      is_expected.to have_css("th.name_field.headerSortDown")
      is_expected.to have_css("tbody#list_rows tr", count: 20)
    end

    it "keeps one row per player when a newer player shifts the batches, including the row page 2 re-delivers" do
      short_window
      FactoryBot.create_list(:player, 45)
      visit index_path(model_name: "player")
      is_expected.to have_css("tbody#list_rows tr", count: 20)
      redelivered = row_ids.last

      FactoryBot.create(:player)
      scroll_until_end
      is_expected.to have_css("tbody#list_rows tr", count: 45)
      expect(row_ids.tally.values).to all(eq 1)
      expect(row_ids).to include(redelivered)
    end

    it "gives an appended row's sticky cell the same left offset as the first row's" do
      RailsAdminNext.config(Player) { list { configure(:name) { sticky true } } }
      FactoryBot.create_list(:player, 45)
      visit index_path(model_name: "player")
      is_expected.to have_css("tbody#list_rows tr", minimum: 40)

      first, appended = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#list_rows tr")].filter((_, index) => index === 0 || index === 39).map((row) => row.querySelector("td.name_field").style.left)
      JS
      expect(first).to match(/\A[1-9][\d.]*px\z/)
      expect(appended).to eq first
    end
  end
end
