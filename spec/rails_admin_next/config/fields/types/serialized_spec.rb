# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::Serialized do
  it_behaves_like "a generic field type", :text_field, :serialized

  describe "round-tripping the edited value" do
    let(:field) { RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :text_field } }
    let(:object) { FieldTest.new }

    before do
      RailsAdminNext.config do |config|
        config.model FieldTest do
          field :text_field, :serialized
        end
      end
    end

    def dump(value)
      allow(object).to receive(:read_attribute).with(:text_field) { value }
      field.with(object:).formatted_value
    end

    def round_trip(value)
      field.parse_value(dump(value))
    end

    it "loads back a store's HashWithIndifferentAccess as a plain Hash" do
      value = ActiveSupport::HashWithIndifferentAccess.new(foo: "bar", nested: {baz: [{qux: 1}]})

      expect(dump(value)).not_to include("!ruby/")
      expect(round_trip(value)).to eq("foo" => "bar", "nested" => {"baz" => [{"qux" => 1}]})
    end

    it "loads back symbols, dates and times" do
      time = Time.utc(2026, 1, 1, 12, 30)

      expect(round_trip([:admin, Date.new(2026, 1, 1), time])).to eq([:admin, Date.new(2026, 1, 1), time])
    end

    it "refuses to load arbitrary classes" do
      expect { field.parse_value("--- !ruby/object:OpenStruct\ntable: {}\n") }.to raise_error(Psych::DisallowedClass)
    end
  end
end
