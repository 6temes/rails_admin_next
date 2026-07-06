# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Extensions::CanCanCan::AuthorizationAdapter do
  let(:user) { double }
  let(:controller) { double(_current_user: user, current_ability: MyAbility.new(user)) }

  before do
    stub_const("MyAbility", Class.new do
      include CanCan::Ability

      def initialize(_user)
        can :access, :rails_admin
        can :manage, :all
      end
    end)
  end

  describe "#initialize" do
    it "accepts the ability class as an argument" do
      expect(described_class.new(controller, MyAbility).ability_class).to eq MyAbility
    end

    it "supports block DSL" do
      adapter = described_class.new(controller) do
        ability_class MyAbility
      end
      expect(adapter.ability_class).to eq MyAbility
    end
  end
end
