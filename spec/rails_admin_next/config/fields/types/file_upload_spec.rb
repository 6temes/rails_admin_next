# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::FileUpload do
  it_behaves_like "a generic field type", :string_field, :file_upload

  describe "#allowed_methods" do
    it "includes delete_method" do
      RailsAdminNext.config do |config|
        config.model FieldTest do
          field :active_storage_asset do
            delete_method :remove_active_storage_asset
          end
        end
      end
      expect(RailsAdminNext.config(FieldTest).field(:active_storage_asset).allowed_methods.collect(&:to_s)).to eq %w[active_storage_asset remove_active_storage_asset]
    end
  end

  describe "#html_attributes" do
    context "when the field is required and value is already set" do
      before do
        RailsAdminNext.config FieldTest do
          field :string_field, :file_upload do
            required true
          end
        end
      end

      let :rails_admin_field do
        RailsAdminNext.config("FieldTest").fields.detect do |f|
          f.name == :string_field
        end.with(object: FieldTest.new(string_field: "dummy.jpg"))
      end

      it "does not have a required attribute" do
        expect(rails_admin_field.html_attributes[:required]).to be_falsy
      end
    end
  end

  describe "#pretty_value" do
    context "when the field is not image" do
      before do
        RailsAdminNext.config FieldTest do
          field :string_field, :file_upload do
            def resource_url
              "http://example.com/dummy.txt"
            end
          end
        end
      end

      let :rails_admin_field do
        RailsAdminNext.config("FieldTest").fields.detect do |f|
          f.name == :string_field
        end.with(
          object: FieldTest.new(string_field: "dummy.txt"),
          view: ApplicationController.new.view_context
        )
      end

      it "uses filename as link text" do
        expect(Nokogiri::HTML(rails_admin_field.pretty_value).text).to eq "dummy.txt"
      end
    end
  end

  describe "#image?" do
    let(:filename) { "dummy.txt" }
    let :rails_admin_field do
      RailsAdminNext.config("FieldTest").fields.detect do |f|
        f.name == :string_field
      end.with(
        object: FieldTest.new(string_field: filename),
        view: ApplicationController.new.view_context
      )
    end
    before do
      RailsAdminNext.config FieldTest do
        field :string_field, :file_upload do
          def resource_url
            "http://example.com/#{value}"
          end
        end
      end
    end

    context "when the file is not an image" do
      let(:filename) { "dummy.txt" }

      it "returns false" do
        expect(rails_admin_field.image?).to be false
      end
    end

    context "when the file is an image" do
      let(:filename) { "dummy.jpg" }

      it "returns true" do
        expect(rails_admin_field.image?).to be true
      end
    end

    context "when the file is an image but suffixed with a query string" do
      let(:filename) { "dummy.jpg?foo=bar" }

      it "returns true" do
        expect(rails_admin_field.image?).to be true
      end
    end

    context "when the filename can't be represented as a valid URI" do
      let(:filename) { "du mmy.jpg" }

      it "returns false" do
        expect(rails_admin_field.image?).to be false
      end
    end
  end
end
