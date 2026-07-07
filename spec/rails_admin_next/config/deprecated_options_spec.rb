# frozen_string_literal: true

require "spec_helper"

# Rails 8.1 made the class-level ActiveSupport::Deprecation.warn private, so every
# deprecated-option shim must go through RailsAdminNext.deprecator (an instance
# deprecator) instead. Each example below touches a deprecated option and asserts
# the warning is emitted via the instance deprecator AND that touching it never raises.
RSpec.describe "deprecated configuration options" do
  describe "the generic register_deprecated_instance_option shim (Configurable)" do
    it "warns via the deprecator and delegates to the replacement, without raising", :aggregate_failures do
      RailsAdminNext.config Team do
        field :players do
          eager_load true
        end
      end
      field = RailsAdminNext.config(Team).fields.detect { |f| f.name == :players }

      expect(RailsAdminNext.deprecator).to receive(:warn).with(/eager_load/)
      expect { expect(field.eager_load?).to eq(true) }.not_to raise_error
    end
  end

  describe "RailsAdminNext::Config.total_columns_width=" do
    it "warns via the deprecator without raising" do
      expect(RailsAdminNext.deprecator).to receive(:warn).with(/total_columns_width/)
      expect { RailsAdminNext.config.total_columns_width = 900 }.not_to raise_error
    end
  end

  describe "RailsAdminNext::Config.sidescroll=" do
    it "warns via the deprecator without raising" do
      expect(RailsAdminNext.deprecator).to receive(:warn).with(/sidescroll/)
      expect { RailsAdminNext.config.sidescroll = false }.not_to raise_error
    end
  end

  describe "RailsAdminNext::Config::Sections::List#sidescroll" do
    it "warns via the deprecator without raising" do
      expect(RailsAdminNext.deprecator).to receive(:warn).with(/sidescroll/)
      expect { RailsAdminNext.config(Player).list.sidescroll }.not_to raise_error
    end
  end

  describe "RailsAdminNext::Config::Sections::List#sort_reverse" do
    it "warns via the deprecator without raising" do
      expect(RailsAdminNext.deprecator).to receive(:warn).with(/sort_reverse/)
      expect { RailsAdminNext.config(Player).list.sort_reverse }.not_to raise_error
    end
  end
end
