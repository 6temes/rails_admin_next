# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::PaginatedCollection do
  it "derives total_pages from total_count and per_page when not given one" do
    collection = described_class.new([1, 2], current_page: 1, per_page: 2, total_count: 5)

    expect(collection.total_pages).to eq(3)
  end

  it "reports at least one page when empty" do
    collection = described_class.new([], current_page: 1, per_page: 20, total_count: 0)

    expect(collection.total_pages).to eq(1)
  end

  it "treats a grouped-relation Hash count as its number of groups" do
    collection = described_class.new([1], current_page: 1, per_page: 20, total_count: {"a" => 3, "b" => 7})

    expect(collection.total_count).to eq(2)
    expect(collection.total_pages).to eq(1)
  end

  it "evaluates and memoizes a count callable lazily" do
    calls = 0
    collection = described_class.new([1], current_page: 1, per_page: 20, total_count: lambda {
      calls += 1
      42
    })

    expect(calls).to eq(0)
    expect(collection.total_count).to eq(42)
    expect(collection.total_count).to eq(42)
    expect(calls).to eq(1)
  end
end
