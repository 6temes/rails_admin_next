# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::Uuid do
  let(:uuid) { SecureRandom.uuid }
  let(:object) { FactoryBot.create(:field_test) }
  let(:field) { RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :uuid_field } }

  before do
    RailsAdminNext.config do |config|
      config.model FieldTest do
        field :uuid_field, :uuid
      end
    end

    allow(object).to receive(:uuid_field).and_return uuid
    field.bindings = {object: object}
  end

  it "field is a Uuid fieldtype" do
    expect(field.class).to eq RailsAdminNext::Config::Fields::Types::Uuid
  end

  it "handles uuid string" do
    expect(field.value).to eq uuid
  end

  it_behaves_like "a generic field type", :string_field, :uuid
end
