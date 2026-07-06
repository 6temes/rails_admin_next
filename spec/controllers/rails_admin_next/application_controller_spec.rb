# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::ApplicationController, type: :controller do
  describe "#to_model_name" do
    it "works with modules" do
      expect(controller.to_model_name("conversations~conversation")).to eq("Conversations::Conversation")
    end
  end

  describe "#_current_user" do
    it "is public" do
      expect { controller._current_user }.not_to raise_error
    end
  end

  describe "#rails_admin_controller?" do
    it "returns true" do
      expect(controller.send(:rails_admin_controller?)).to be true
    end
  end
end
