# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Actions::Base do
  describe "#enabled?" do
    it "excludes models not referenced in the only array" do
      RailsAdminNext.config do |config|
        config.actions do
          index do
            only [Player, Cms::BasicPage]
          end
        end
      end
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Player))).to be_enabled
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Team))).to be_nil
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Cms::BasicPage))).to be_enabled
    end

    it "excludes models referenced in the except array" do
      RailsAdminNext.config do |config|
        config.actions do
          index do
            except [Player, Cms::BasicPage]
          end
        end
      end
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Player))).to be_nil
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Team))).to be_enabled
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Cms::BasicPage))).to be_nil
    end

    it "is always true for a writable model" do
      RailsAdminNext.config do |config|
        config.actions do
          index
          show
          new
          edit
          delete
        end
      end
      %i[index show new edit delete].each do |action|
        expect(RailsAdminNext::Config::Actions.find(action, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Player), object: Player.new)).to be_enabled
      end
    end

    it "is false for write operations of a read-only model" do
      RailsAdminNext.config do |config|
        config.actions do
          index
          show
          new
          edit
          delete
        end
      end
      expect(RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(ReadOnlyComment))).to be_enabled
      expect(RailsAdminNext::Config::Actions.find(:show, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(ReadOnlyComment), object: ReadOnlyComment.new)).to be_enabled
      expect(RailsAdminNext::Config::Actions.find(:new, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(ReadOnlyComment))).to be_enabled
      expect(RailsAdminNext::Config::Actions.find(:edit, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(ReadOnlyComment), object: ReadOnlyComment.new)).to be_nil
      expect(RailsAdminNext::Config::Actions.find(:delete, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(ReadOnlyComment), object: ReadOnlyComment.new)).to be_nil
    end
  end

  describe "#linkable?" do
    def index_action
      RailsAdminNext::Config::Actions.find(:index, controller: double(authorized?: true), abstract_model: RailsAdminNext::AbstractModel.new(Player))
    end

    it "is true for the default GET-only action" do
      expect(index_action).to be_linkable
    end

    it "is true when the verb is written as an uppercase symbol" do
      RailsAdminNext.config do |config|
        config.actions { index { http_methods %i[GET] } }
      end

      expect(index_action).to be_linkable
    end

    it "is true when the verb is written as a string" do
      RailsAdminNext.config do |config|
        config.actions { index { http_methods %w[get] } }
      end

      expect(index_action).to be_linkable
    end

    it "is false without a GET among the verbs" do
      RailsAdminNext.config do |config|
        config.actions { index { http_methods %i[post put] } }
      end

      expect(index_action).not_to be_linkable
    end
  end
end
