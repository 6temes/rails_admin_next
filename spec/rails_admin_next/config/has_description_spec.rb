# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::HasDescription do
  it "shows description message when added through the DSL" do
    RailsAdminNext.config do |config|
      config.model Team do
        desc "Description of Team model"
      end
    end

    expect(RailsAdminNext.config(Team).description).to eq("Description of Team model")
  end
end
