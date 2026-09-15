# frozen_string_literal: true

require "spec_helper"

# Rails 8.1 made the class-level ActiveSupport::Deprecation.warn private, so the shim
# must go through RailsAdminNext.deprecator (an instance deprecator) instead. The engine
# declares no deprecated options of its own any more, but extensions and host apps use
# this mechanism for theirs, so it stays covered.
RSpec.describe RailsAdminNext::Config::Configurable do
  let(:configurable) do
    Class.new do
      include RailsAdminNext::Config::Configurable

      register_instance_option :replacement do
        "the value"
      end
    end.new
  end

  describe "an option with a replacement" do
    it "warns via the deprecator and delegates, without raising", :aggregate_failures do
      configurable.register_deprecated_instance_option :legacy, :replacement

      expect(RailsAdminNext.deprecator).to receive(:warn).with(/legacy.*replacement/)
      expect(configurable.legacy).to eq("the value")
    end
  end

  describe "an option removed with a custom message" do
    it "yields the block instead of raising" do
      configurable.register_deprecated_instance_option :legacy do
        RailsAdminNext.deprecator.warn("The legacy configuration option was removed.")
      end

      expect(RailsAdminNext.deprecator).to receive(:warn).with(/legacy/)
      configurable.legacy
    end
  end

  describe "an option removed without a replacement" do
    it "raises, so the host is not left believing it still applies" do
      configurable.register_deprecated_instance_option :legacy

      expect { configurable.legacy }.to raise_error(/legacy.*removed without replacement/)
    end
  end
end
