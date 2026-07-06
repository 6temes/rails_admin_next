# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Engine do
  context "on class unload" do
    let(:fields) { RailsAdminNext.config(Player).edit.fields }
    before do
      Rails.application.config.cache_classes = false
      RailsAdminNext.config(Player) do
        field :name
        field :number
      end
    end
    after { Rails.application.config.cache_classes = true }

    it "triggers RailsAdminNext config to be reloaded" do
      # this simulates rails code reloading
      RailsAdminNext::Engine.initializers.find do |i|
        i.name == "RailsAdminNext reload config in development"
      end.block.call(Rails.application)
      Rails.application.executor.wrap do
        ActiveSupport::Reloader.new.tap(&:class_unload!).complete!
      end

      RailsAdminNext.config(Player) do
        field :number
      end
      expect(fields.map(&:name)).to match_array %i[number]
    end
  end
end
