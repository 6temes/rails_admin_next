# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext do
  describe ".yaml_load" do
    it "still safe-loads, with a deprecation warning", :aggregate_failures do
      expect(described_class.deprecator).to receive(:warn).with(/yaml_load/)
      expect(described_class.yaml_load("- a\n")).to eq(%w[a])
    end
  end

  describe ".yaml_dump" do
    it "still dumps, with a deprecation warning", :aggregate_failures do
      expect(described_class.deprecator).to receive(:warn).with(/yaml_dump/)
      expect(described_class.yaml_dump(%w[a])).to eq("---\n- a\n")
    end
  end
end
