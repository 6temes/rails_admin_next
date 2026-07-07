# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::Boolean do
  it_behaves_like "a generic field type", :boolean_field, :boolean

  subject do
    RailsAdminNext.config(FieldTest).fields.detect do |f|
      f.name == :boolean_field
    end.with(object: test_object)
  end

  describe "#pretty_value" do
    {
      false => %(<span class="badge bg-danger">#{RailsAdminNext::Icons.svg(:cancel)}</span>),
      true => %(<span class="badge bg-success">#{RailsAdminNext::Icons.svg(:check)}</span>),
      nil => %(<span class="badge bg-default">#{RailsAdminNext::Icons.svg(:minus)}</span>)
    }.each do |field_value, expected_result|
      context "when field value is '#{field_value.inspect}'" do
        let(:test_object) { FieldTest.new(boolean_field: field_value) }

        it "returns the appropriate html result" do
          expect(subject.pretty_value).to eq(expected_result)
        end
      end
    end
  end
end
