# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Support::CompositeKeysSerializer do
  def round_trip(keys)
    described_class.deserialize(described_class.serialize(keys))
  end

  it "round-trips values that contain the separator", :aggregate_failures do
    expect(round_trip(["a_", "b"])).to eq(["a_", "b"])
    expect(round_trip(["a", "_b"])).to eq(["a", "_b"])
    expect(round_trip(["a__b", "c_d"])).to eq(["a__b", "c_d"])
  end

  it "round-trips an empty trailing value" do
    expect(round_trip(["a", ""])).to eq(["a", ""])
  end

  it "round-trips values that contain the escape character" do
    expect(round_trip(["a~5F", "~"])).to eq(["a~5F", "~"])
  end

  # Serialized ids are URL path segments, so anything already linked must keep its address.
  it "leaves values without an underscore or tilde unchanged", :aggregate_failures do
    expect(described_class.serialize([1, 2, 3])).to eq("1_2_3")
    expect(described_class.serialize(["a-b", "c.d"])).to eq("a-b_c.d")
  end
end
