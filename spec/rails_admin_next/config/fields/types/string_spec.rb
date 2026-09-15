# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::String do
  context "with a string column" do
    before :each do
      RailsAdminNext.config Ball do
        field "color", :string
      end
    end

    let(:string_field) do
      RailsAdminNext.config("Ball").fields.detect do |f|
        f.name == :color
      end.with(object: Ball.new)
    end

    describe "#html_attributes" do
      it "should contain a size attribute" do
        expect(string_field.html_attributes[:size]).to be_present
      end

      it "should not contain a size attribute valorized with 0" do
        expect(string_field.html_attributes[:size]).to_not be_zero
      end
    end

    describe "#valid_length" do
      def stub_length_validator(**options)
        validator = ActiveModel::Validations::LengthValidator.new(attributes: [:color], **options)
        allow(Ball).to receive(:validators_on).with(:color).and_return([validator])
      end

      it "drops bounds given as a Proc", :aggregate_failures do
        stub_length_validator(minimum: -> { 6 }, maximum: -> { 128 })

        expect(string_field.valid_length).to eq({})
        expect(string_field.generic_help).to eq("Optional. ")
      end

      it "drops bounds given as a Symbol", :aggregate_failures do
        stub_length_validator(minimum: :min_color_length, maximum: :max_color_length)

        expect(string_field.valid_length).to eq({})
        expect(string_field.generic_help).to eq("Optional. ")
      end

      it "drops an exact length given as a Proc", :aggregate_failures do
        stub_length_validator(is: -> { 8 })

        expect(string_field.valid_length).to eq({})
        expect(string_field.generic_help).to eq("Optional. ")
      end

      it "drops an exact length given as a Symbol", :aggregate_failures do
        stub_length_validator(is: :exact_color_length)

        expect(string_field.valid_length).to eq({})
        expect(string_field.generic_help).to eq("Optional. ")
      end

      it "keeps bounds given as integers", :aggregate_failures do
        stub_length_validator(minimum: 6, maximum: 128)

        expect(string_field.valid_length).to include(minimum: 6, maximum: 128)
        expect(string_field.generic_help).to eq("Optional. Length of 6-128.")
      end

      it "keeps an exact length given as an integer", :aggregate_failures do
        stub_length_validator(is: 8)

        expect(string_field.valid_length).to include(is: 8)
        expect(string_field.generic_help).to eq("Optional. Length of 8.")
      end

      it "keeps options that are not length bounds" do
        condition = -> { true }
        stub_length_validator(maximum: 128, if: condition)

        expect(string_field.valid_length).to include(maximum: 128, if: condition)
      end
    end
  end

  it_behaves_like "a generic field type", :string_field

  it_behaves_like "a string-like field type", :string_field
end
