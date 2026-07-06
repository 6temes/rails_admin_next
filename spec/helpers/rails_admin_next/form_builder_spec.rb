# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAdminNext::FormBuilder", type: :helper do
  describe "#generate" do
    before do
      RailsAdminNext.config Player do
        create do
          include_all_fields
          field :number, :hidden
        end
      end
      # The real admin view always has the engine helpers (rails_admin_icon, used by
      # the rendered partials); the bare helper-spec view does not, so include them.
      helper.extend(RailsAdminNext::ApplicationHelper)
      allow(helper).to receive(:authorized?).and_return(true)
      (@object = Player.new).save
      @builder = RailsAdminNext::FormBuilder.new(:player, @object, helper, {})
      allow(@builder).to receive(:field_for).and_return("field")
      action = double
      allow(action).to receive(:enabled?).and_return true
      helper.instance_variable_set :@action, action
    end

    it "does not add additional error div from default ActionView::Base.field_error_proc" do
      expect(@builder.generate(action: :create, model_config: RailsAdminNext.config(Player))).not_to have_css(".field_with_errors")
      expect(@builder.generate(action: :create, model_config: RailsAdminNext.config(Player))).to have_css(".control-group.error")
    end

    it "hidden fields should be wrapper" do
      expect(@builder.generate(action: :create, model_config: RailsAdminNext.config(Player))).to match("control-group row mb-3 hidden_type number_field")
    end
  end

  describe "#object_infos" do
    before do
      allow(helper).to receive(:authorized?).and_return(true)
      @object = Fan.create!(name: "foo")
      @builder = RailsAdminNext::FormBuilder.new(:fan, @object, helper, {})
    end

    it "returns a tag with infos" do
      expect(@builder.object_infos).to eql '<span hidden class="object-infos" data-model-label="Fan" data-object-label="foo"></span>'
    end

    context "when object_label's type is symbol" do
      before { @object.name = :foo }

      it "does not break" do
        expect(@builder.object_infos).to eql '<span hidden class="object-infos" data-model-label="Fan" data-object-label="foo"></span>'
      end
    end
  end
end
