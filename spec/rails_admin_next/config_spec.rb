# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config do
  describe ".included_models" do
    it "only uses included models" do
      RailsAdminNext.config.included_models = [Team, League]
      expect(RailsAdminNext::AbstractModel.all.collect(&:model)).to eq([League, Team]) # it gets sorted
    end

    it "does not restrict models if included_models is left empty" do
      RailsAdminNext.config.included_models = []
      expect(RailsAdminNext::AbstractModel.all.collect(&:model)).to include(Team, League)
    end

    it "removes excluded models (whitelist - blacklist)" do
      RailsAdminNext.config.excluded_models = [Team]
      RailsAdminNext.config.included_models = [Team, League]
      expect(RailsAdminNext::AbstractModel.all.collect(&:model)).to eq([League])
    end

    it "excluded? returns true for any model not on the list" do
      RailsAdminNext.config.included_models = [Team, League]

      team_config = RailsAdminNext::AbstractModel.new("Team").config
      fan_config = RailsAdminNext::AbstractModel.new("Fan").config

      expect(fan_config).to be_excluded
      expect(team_config).not_to be_excluded
    end
  end

  describe ".color_scheme" do
    it "defaults to :auto" do
      expect(RailsAdminNext.config.color_scheme).to eq(:auto)
    end

    it "can be pinned to :light or :dark", :aggregate_failures do
      RailsAdminNext.config do |config|
        config.color_scheme = :dark
      end
      expect(RailsAdminNext.config.color_scheme).to eq(:dark)

      RailsAdminNext.config do |config|
        config.color_scheme = :light
      end
      expect(RailsAdminNext.config.color_scheme).to eq(:light)
    end

    it "rejects unsupported values at configuration time" do
      expect { RailsAdminNext.config { |config| config.color_scheme = "dark" } }
        .to raise_error(ArgumentError, /color_scheme must be/)
    end

    it "restores :auto on reset" do
      RailsAdminNext.config.color_scheme = :dark
      RailsAdminNext::Config.reset
      expect(RailsAdminNext.config.color_scheme).to eq(:auto)
    end
  end

  describe ".asset_source" do
    it "always reports the importmap pipeline" do
      expect(RailsAdminNext.config.asset_source).to eq(:importmap)
    end

    it "deprecates and ignores assignment" do
      expect(RailsAdminNext.deprecator).to receive(:warn).with(/asset_source/)
      RailsAdminNext.config.asset_source = :sprockets
      expect(RailsAdminNext.config.asset_source).to eq(:importmap)
    end
  end

  describe ".add_extension" do
    before do
      silence_warnings do
        RailsAdminNext.const_set(:EXTENSIONS, [])
      end
    end

    it "registers the extension with RailsAdminNext" do
      RailsAdminNext.add_extension(:example, ExampleModule)
      expect(RailsAdminNext::EXTENSIONS.count { |name| name == :example }).to eq(1)
    end

    context "given an extension with an authorization adapter" do
      it "registers the adapter" do
        RailsAdminNext.add_extension(:example, ExampleModule, authorization: true)
        expect(RailsAdminNext::AUTHORIZATION_ADAPTERS[:example]).to eq(ExampleModule::AuthorizationAdapter)
      end
    end

    context "given an extension with an auditing adapter" do
      it "registers the adapter" do
        RailsAdminNext.add_extension(:example, ExampleModule, auditing: true)
        expect(RailsAdminNext::AUDITING_ADAPTERS[:example]).to eq(ExampleModule::AuditingAdapter)
      end
    end

    context "given an extension with a configuration adapter" do
      it "registers the adapter" do
        RailsAdminNext.add_extension(:example, ExampleModule, configuration: true)
        expect(RailsAdminNext::CONFIGURATION_ADAPTERS[:example]).to eq(ExampleModule::ConfigurationAdapter)
      end
    end
  end

  describe ".authorize_with" do
    context "given a key for a extension with authorization" do
      before do
        RailsAdminNext.add_extension(:example, ExampleModule, authorization: true)
      end

      it "initializes the authorization adapter" do
        expect(ExampleModule::AuthorizationAdapter).to receive(:new).with(RailsAdminNext::Config)
        RailsAdminNext.config do |config|
          config.authorize_with(:example)
        end
        RailsAdminNext.config.authorize_with.call
      end

      it "passes through any additional arguments to the initializer" do
        options = {option: true}
        expect(ExampleModule::AuthorizationAdapter).to receive(:new).with(RailsAdminNext::Config, options)
        RailsAdminNext.config do |config|
          config.authorize_with(:example, options)
        end
        RailsAdminNext.config.authorize_with.call
      end
    end
  end

  describe ".audit_with" do
    context "given a key for a extension with auditing" do
      before do
        RailsAdminNext.add_extension(:example, ExampleModule, auditing: true)
      end

      it "initializes the auditing adapter" do
        expect(ExampleModule::AuditingAdapter).to receive(:new).with(RailsAdminNext::Config)
        RailsAdminNext.config do |config|
          config.audit_with(:example)
        end
        RailsAdminNext.config.audit_with.call
      end

      it "passes through any additional arguments to the initializer" do
        options = {option: true}
        expect(ExampleModule::AuditingAdapter).to receive(:new).with(RailsAdminNext::Config, options)
        RailsAdminNext.config do |config|
          config.audit_with(:example, options)
        end
        RailsAdminNext.config.audit_with.call
      end
    end

    context "given paper_trail as the extension for auditing", active_record: true do
      before do
        stub_const("ControllerMock", Class.new {
          def set_paper_trail_whodunnit
          end
        })
        stub_const("Version", Class.new)

        RailsAdminNext.add_extension(:example, RailsAdminNext::Extensions::PaperTrail, auditing: true)
      end

      it "initializes the auditing adapter" do
        RailsAdminNext.config do |config|
          config.audit_with(:example)
        end
        expect { ControllerMock.new.instance_eval(&RailsAdminNext.config.audit_with) }.not_to raise_error
      end
    end
  end

  describe ".configure_with" do
    context "given a key for a extension with configuration" do
      before do
        RailsAdminNext.add_extension(:example, ExampleModule, configuration: true)
      end

      it "initializes configuration adapter" do
        expect(ExampleModule::ConfigurationAdapter).to receive(:new)
        RailsAdminNext.config do |config|
          config.configure_with(:example)
        end
      end

      it "yields the (optionally) provided block, passing the initialized adapter" do
        configurator = nil
        RailsAdminNext.config do |config|
          config.configure_with(:example) do |configuration_adapter|
            configurator = configuration_adapter
          end
        end
        expect(configurator).to be_a(ExampleModule::ConfigurationAdapter)
      end
    end
  end

  describe ".config" do
    context ".default_search_operator" do
      it "sets the default_search_operator" do
        RailsAdminNext.config do |config|
          config.default_search_operator = "starts_with"
        end
        expect(RailsAdminNext::Config.default_search_operator).to eq("starts_with")
      end

      it "errors on unrecognized search operator" do
        expect do
          RailsAdminNext.config do |config|
            config.default_search_operator = "random"
          end
        end.to raise_error(ArgumentError, "Search operator 'random' not supported")
      end

      it "defaults to 'default'" do
        expect(RailsAdminNext::Config.default_search_operator).to eq("default")
      end
    end
  end

  describe ".visible_models" do
    it "passes controller bindings, find visible models, order them" do
      RailsAdminNext.config do |config|
        config.included_models = [Player, Fan, Comment, Team]

        config.model Player do
          hide
        end
        config.model Fan do
          weight(-1)
          show
        end
        config.model Comment do
          visible do
            bindings[:controller]._current_user.role == :admin
          end
        end
        config.model Team do
          visible do
            bindings[:controller]._current_user.role != :admin
          end
        end
      end

      expect(RailsAdminNext.config.visible_models(controller: double(_current_user: double(role: :admin), authorized?: true)).collect(&:abstract_model).collect(&:model)).to match_array [Fan, Comment]
    end

    it "hides unallowed models" do
      RailsAdminNext.config do |config|
        config.included_models = [Comment]
      end
      expect(RailsAdminNext.config.visible_models(controller: double(authorization_adapter: double(authorized?: true))).collect(&:abstract_model).collect(&:model)).to eq([Comment])
      expect(RailsAdminNext.config.visible_models(controller: double(authorization_adapter: double(authorized?: false))).collect(&:abstract_model).collect(&:model)).to eq([])
    end
  end

  describe ".models_pool" do
    it "should not include classnames start with Concerns::" do
      expect(RailsAdminNext::Config.models_pool.select { |m| m.match(/^Concerns::/) }).to be_empty
    end

    it "includes models in the directory added by config.eager_load_paths" do
      expect(RailsAdminNext::Config.models_pool).to include("Basketball")
    end

    it "should include a model which was configured explicitly" do
      RailsAdminNext::Config.model "PaperTrail::Version" do
        visible false
      end

      expect(RailsAdminNext::Config.models_pool).to include("PaperTrail::Version")
    end
  end

  describe ".parent_controller" do
    before do
      stub_const("TestController", Class.new(ActionController::Base))
    end

    it "uses default class" do
      expect(RailsAdminNext.config.parent_controller).to eq "::ActionController::Base"
    end

    it "uses other class" do
      RailsAdminNext.config do |config|
        config.parent_controller = "TestController"
      end
      expect(RailsAdminNext.config.parent_controller).to eq "TestController"
    end
  end

  describe ".parent_controller=" do
    context "if RailsAdminNext::ApplicationController is already loaded" do
      before do
        # preload controllers (e.g. when config.eager_load = true)
        RailsAdminNext::MainController
      end

      after do
        RailsAdminNext::Config.reset
        RailsAdminNext.send(:remove_const, :ApplicationController)
        load RailsAdminNext::Engine.root.join("app/controllers/rails_admin_next/application_controller.rb")
      end

      it "can be changed" do
        RailsAdminNext.config.parent_controller = "ApplicationController"
        expect(RailsAdminNext::ApplicationController.superclass).to eq ApplicationController
        expect(RailsAdminNext::MainController.superclass.superclass).to eq ApplicationController
      end
    end
  end

  describe ".model" do
    let(:fields) { described_class.model(Team).fields }
    before do
      described_class.model Team do
        field :players do
          visible false
        end
      end
    end

    context "when model expanded" do
      before do
        described_class.model(Team) do
          field :fans
        end
      end
      it "execute all passed blocks" do
        expect(fields.map(&:name)).to match_array %i[players fans]
      end
    end

    context "when expand redefine behavior" do
      before do
        described_class.model Team do
          field :players
        end
      end
      it "execute all passed blocks" do
        expect(fields.find { |f| f.name == :players }.visible).to be true
      end
    end

    context "when model has no table yet", active_record: true do
      it "does not try to apply the configuration block" do
        described_class.model(WithoutTable) do
          include_all_fields
        end
      end
    end
  end

  describe ".reset" do
    before do
      RailsAdminNext.config do |config|
        config.included_models = %w[Player Team]
      end
      RailsAdminNext::AbstractModel.all
      RailsAdminNext::Config.reset
      RailsAdminNext.config do |config|
        config.excluded_models = ["Player"]
      end
    end
    subject { RailsAdminNext::AbstractModel.all.map { |am| am.model.name } }

    it "refreshes the result of RailsAdminNext::AbstractModel.all" do
      expect(subject).not_to include "Player"
      expect(subject).to include "Team"
    end
  end

  describe ".reload!" do
    before do
      RailsAdminNext.config Player do
        field :name
      end
      RailsAdminNext.config Team do
        field :color, :integer
      end
    end

    it "clears current configuration" do
      RailsAdminNext::Config.reload!
      expect(RailsAdminNext::Config.model(Player).fields.map(&:name)).to include :number
    end

    it "reloads the configuration from the initializer" do
      RailsAdminNext::Config.reload!
      expect(RailsAdminNext::Config.model(Team).fields.find { |f| f.name == :color }.type).to eq :hidden
    end
  end
end

module ExampleModule
  class AuthorizationAdapter; end

  class ConfigurationAdapter; end

  class AuditingAdapter; end
end

# Ensures `defined?(::PaperTrail)` is true for RailsAdminNext::Extensions::PaperTrail::AuditingAdapter.setup,
# reopening the real gem's module (see ".audit_with" > "given paper_trail as the extension for auditing").
module PaperTrail; end
