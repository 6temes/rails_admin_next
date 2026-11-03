# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAdminNext with an adapter assigned by the authorize_with block", type: :request do
  let(:adapter_without_authorize) do
    Class.new do
      def authorized?(*) = true

      def query(*) = nil

      def attributes_for(*) = {}
    end
  end

  before do
    adapter_class = adapter_without_authorize
    RailsAdminNext.config do |c|
      c.authorize_with { @authorization_adapter = adapter_class.new }
    end
  end

  it "raises on an action instead of running it unauthorized" do
    expect { get index_path(model_name: "player") }.to raise_error(NoMethodError, /authorize/)
  end
end
