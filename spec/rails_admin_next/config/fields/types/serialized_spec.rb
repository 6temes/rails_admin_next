# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::Serialized do
  it_behaves_like "a generic field type", :text_field, :serialized
end
