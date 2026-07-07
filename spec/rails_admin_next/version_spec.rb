# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAdminNext::Version" do
  it "reports the 1.0.0 fork reset" do
    expect(RailsAdminNext::Version.to_s).to eq("1.0.0")
  end
end
