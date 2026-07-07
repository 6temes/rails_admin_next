# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::AbstractModel do
  describe ".all" do
    it "returns abstract models for all models" do
      expect(RailsAdminNext::AbstractModel.all.map(&:model)).to include Player, Team
    end

    it "does not pick up a model without table", active_record: true do
      expect(RailsAdminNext::AbstractModel.all.map(&:model)).not_to include WithoutTable
    end
  end

  describe ".new" do
    context "on ActiveRecord::NoDatabaseError", active_record: true do
      before do
        expect(WithoutTable).to receive(:table_exists?).and_raise(ActiveRecord::NoDatabaseError)
      end

      it "does not raise error and returns nil" do
        expect(RailsAdminNext::AbstractModel.new("WithoutTable")).to eq nil
      end
    end

    context "on ActiveRecord::ConnectionNotEstablished", active_record: true do
      before do
        expect(WithoutTable).to receive(:table_exists?).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "does not raise error and returns nil" do
        expect(RailsAdminNext::AbstractModel.new("WithoutTable")).to eq nil
      end
    end
  end

  describe "#to_s" do
    it "returns model's name" do
      expect(RailsAdminNext::AbstractModel.new(Cms::BasicPage).to_s).to eq Cms::BasicPage.to_s
    end
  end

  describe "#to_param" do
    it "turns namespaces into prefixes with ~" do
      expect(RailsAdminNext::AbstractModel.new("Cms::BasicPage").to_param).to eq("cms~basic_page")
    end
  end

  describe "filters" do
    before do
      @abstract_model = RailsAdminNext::AbstractModel.new("FieldTest")
    end

    context "ActiveModel::ForbiddenAttributesProtection" do
      it "is present" do
        @abstract_model.model.ancestors.collect(&:to_s).include?("ActiveModel::ForbiddenAttributesProtection")
      end
    end

    context "on ActiveRecord native enum", active_record: true do
      shared_examples "filter on enum" do
        before do
          %w[S M L].each do |size|
            FactoryBot.create(:field_test, string_enum_field: size)
          end

          %w[small medium large].each do |size|
            FactoryBot.create(:field_test, integer_enum_field: size)
          end
        end
        let(:model) { RailsAdminNext::AbstractModel.new("FieldTest") }
        let(:filters) { {enum_field => {"1" => {v: filter_value, o: "is"}}} }
        subject(:elements) { model.all(filters: filters) }

        it "lists elements by value" do
          expect(elements.count).to eq(expected_elements_count)
          expect(elements.map(&enum_field.to_sym)).to all(eq(enum_label))
        end
      end

      context "when enum is integer enum" do
        it_behaves_like "filter on enum" do
          let(:filter_value) { 0 }
          let(:enum_field) { "integer_enum_field" }
          let(:enum_label) { "small" }
          let(:expected_elements_count) { 1 }
        end
      end

      context "when enum is string enum where label <> value" do
        it_behaves_like "filter on enum" do
          let(:filter_value) { "s" }
          let(:enum_field) { "string_enum_field" }
          let(:enum_label) { "S" }
          let(:expected_elements_count) { 1 }
        end
      end
    end

    context "on dates" do
      before do
        [Date.new(2012, 1, 1), Date.new(2012, 1, 2), Date.new(2012, 1, 3), Date.new(2012, 1, 4)].each do |date|
          FactoryBot.create(:field_test, date_field: date)
        end
      end

      it "lists elements within outbound limits" do
        expect(@abstract_model.all(filters: {"date_field" => {"1" => {v: ["", "2012-01-02", "2012-01-03"], o: "between"}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {"date_field" => {"1" => {v: ["", "2012-01-02", "2012-01-02"], o: "between"}}}).count).to eq(1)
        expect(@abstract_model.all(filters: {"date_field" => {"1" => {v: ["", "2012-01-03", ""], o: "between"}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {"date_field" => {"1" => {v: ["", "", "2012-01-02"], o: "between"}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {"date_field" => {"1" => {v: ["2012-01-02"], o: "default"}}}).count).to eq(1)
      end
    end

    context "on datetimes" do
      before do
        I18n.locale = :en
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 1, 23, 59, 59))
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 2, 0, 0, 0))
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 3, 23, 59, 59))
        FactoryBot.create(:field_test, datetime_field: Time.zone.local(2012, 1, 4, 0, 0, 0))
      end

      it "lists elements within outbound limits" do
        expect(@abstract_model.all(filters: {"datetime_field" => {"1" => {v: ["", "2012-01-02T00:00:00", "2012-01-03T23:59:59"], o: "between"}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {"datetime_field" => {"1" => {v: ["", "2012-01-02T00:00:00", "2012-01-03T12:00:00"], o: "between"}}}).count).to eq(1)
        expect(@abstract_model.all(filters: {"datetime_field" => {"1" => {v: ["", "2012-01-03T12:00:00", ""], o: "between"}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {"datetime_field" => {"1" => {v: ["", "", "2012-01-02T12:00:00"], o: "between"}}}).count).to eq(2)
        expect(@abstract_model.all(filters: {"datetime_field" => {"1" => {v: ["2012-01-02T00:00:00"], o: "default"}}}).count).to eq(1)
      end
    end
  end

  context "with pagination", active_record: true do
    before do
      FactoryBot.create_list(:player, 5)
      @abstract_model = RailsAdminNext::AbstractModel.new("Player")
    end

    it "returns a single page of records carrying pagination metadata", :aggregate_failures do
      collection = @abstract_model.all(sort: PK_COLUMN, page: 1, per: 2)
      expect(collection.count).to eq(2)
      expect(collection.current_page).to eq(1)
      expect(collection.total_count).to eq(5)
      expect(collection.total_pages).to eq(3)
    end

    it "offsets to the requested page", :aggregate_failures do
      collection = @abstract_model.all(sort: PK_COLUMN, page: 3, per: 2)
      expect(collection.current_page).to eq(3)
      expect(collection.count).to eq(1)
    end
  end

  describe "each_associated_children" do
    before do
      @abstract_model = RailsAdminNext::AbstractModel.new("Player")
      @draft = FactoryBot.build :draft
      @comments = FactoryBot.build_list :comment, 2
      @player = FactoryBot.build :player, draft: @draft, comments: @comments
    end

    it "should return has_one and has_many associations with its children" do
      @abstract_model.each_associated_children(@player) do |association, children|
        expected =
          case association.name
          when :draft
            [@draft]
          when :comments
            @comments
          end
        expect(children).to eq expected
      end
    end
  end
end
