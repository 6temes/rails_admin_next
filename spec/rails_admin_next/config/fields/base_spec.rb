# frozen_string_literal: true

require "spec_helper"

POLYMORPHIC_CHILDREN = %i[commentable_id commentable_type].freeze

RSpec.describe RailsAdminNext::Config::Fields::Base do
  describe "#required" do
    it "reads the on: :create/:update validate option" do
      RailsAdminNext.config Ball do
        field "color"
      end

      expect(RailsAdminNext.config("Ball").fields.first.with(object: Ball.new)).to be_required
      expect(RailsAdminNext.config("Ball").fields.first.with(object: FactoryBot.create(:ball))).not_to be_required
    end

    context "without validation" do
      it "is optional" do
        # draft.notes is nullable and has no validation
        field = RailsAdminNext.config("Draft").edit.fields.detect { |f| f.name == :notes }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_falsey
      end
    end

    context "with presence validation" do
      it "is required" do
        # draft.date is nullable in the schema but has an AR
        # validates_presence_of validation that makes it required
        field = RailsAdminNext.config("Draft").edit.fields.detect { |f| f.name == :date }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_truthy
      end
    end

    context "with numericality validation" do
      it "is required" do
        # draft.round is nullable in the schema but has an AR
        # validates_numericality_of validation that makes it required
        field = RailsAdminNext.config("Draft").edit.fields.detect { |f| f.name == :round }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_truthy
      end
    end

    context "with validation marked as allow_nil or allow_blank" do
      it "is optional" do
        # team.revenue is nullable in the schema but has an AR
        # validates_numericality_of validation that allows nil
        field = RailsAdminNext.config("Team").edit.fields.detect { |f| f.name == :revenue }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_falsey

        # team.founded is nullable in the schema but has an AR
        # validates_numericality_of validation that allows blank
        field = RailsAdminNext.config("Team").edit.fields.detect { |f| f.name == :founded }
        expect(field.properties.nullable?).to be_truthy
        expect(field.required?).to be_falsey
      end
    end

    context "with conditional validation" do
      before do
        stub_const("ConditionalValidationTest", Class.new(Tableless) do
          column :foo, :varchar
          column :bar, :varchar
          validates :foo, presence: true, if: :persisted?
          validates :bar, presence: true, unless: :persisted?
        end)
      end

      it "is optional" do
        expect(RailsAdminNext.config("ConditionalValidationTest").fields.detect { |f| f.name == :foo }).not_to be_required
        expect(RailsAdminNext.config("ConditionalValidationTest").fields.detect { |f| f.name == :bar }).not_to be_required
      end
    end

    context "on an ActiveStorage installation" do
      it "should detect required fields" do
        expect(RailsAdminNext.config("Image").fields.detect { |f| f.name == :file }.with(object: Image.new)).to be_required
      end
    end

    describe "associations" do
      before do
        stub_const("RelTest", Class.new(Tableless) do
          column :league_id, :integer
          column :division_id, :integer, nil, false
          column :player_id, :integer
          belongs_to :league, optional: true
          belongs_to :division, optional: true
          belongs_to :player, optional: true
          validates_numericality_of(:player_id, only_integer: true)
        end)
        @fields = RailsAdminNext.config(RelTest).create.fields
      end

      describe "for column with nullable foreign key and no model validations" do
        it "is optional" do
          expect(@fields.detect { |f| f.name == :league }.required?).to be_falsey
        end
      end

      describe "for column with non-nullable foreign key and no model validations" do
        it "is optional" do
          expect(@fields.detect { |f| f.name == :division }.required?).to be_falsey
        end
      end

      describe "for column with nullable foreign key and a numericality model validation" do
        it "is required" do
          expect(@fields.detect { |f| f.name == :player }.required?).to be_truthy
        end
      end
    end
  end

  describe "#name" do
    it "is normalized to Symbol" do
      RailsAdminNext.config Team do
        field "name"
      end
      expect(RailsAdminNext.config("Team").fields.first.name).to eq(:name)
    end
  end

  describe "#children_fields" do
    it "is empty by default" do
      expect(RailsAdminNext.config(Team).fields.detect { |f| f.name == :name }.children_fields).to eq([])
    end

    it "contains child key for belongs to associations" do
      expect(RailsAdminNext.config(Team).fields.detect { |f| f.name == :division }.children_fields).to eq([:division_id])
    end

    it "contains child keys for polymorphic belongs to associations" do
      expect(RailsAdminNext.config(Comment).fields.detect { |f| f.name == :commentable }.children_fields).to match_array POLYMORPHIC_CHILDREN
    end

    it "has correct fields when polymorphic_type column comes ahead of polymorphic foreign_key column" do
      stub_const("CommentReversed", Class.new(Tableless) do
        column :commentable_type, :varchar
        column :commentable_id, :integer
        belongs_to :commentable, polymorphic: true
      end)
      expect(RailsAdminNext.config(CommentReversed).fields.collect { |f| f.name.to_s }.select { |f| /^comment/ =~ f }).to match_array ["commentable"].concat(POLYMORPHIC_CHILDREN.collect(&:to_s))
    end

    if defined?(ActiveStorage)
      context "of a ActiveStorage installation" do
        it "is _attachment and _blob fields" do
          expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :active_storage_asset }.children_fields).to match_array %i[active_storage_asset_attachment active_storage_asset_blob]
        end

        it "is hidden, not filterable" do
          fields = RailsAdminNext.config(FieldTest).fields.select { |f| %i[active_storage_asset_attachment active_storage_asset_blob].include?(f.name) }
          expect(fields).to all(be_hidden)
          expect(fields).not_to include(be_filterable)
        end
      end

      context "of a ActiveStorage installation with multiple file support" do
        it "is _attachment and _blob fields" do
          expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :active_storage_assets }.children_fields).to match_array %i[active_storage_assets_attachments active_storage_assets_blobs]
        end

        it "is hidden, not filterable" do
          fields = RailsAdminNext.config(FieldTest).fields.select { |f| %i[active_storage_assets_attachments active_storage_assets_blobs].include?(f.name) }
          expect(fields).to all(be_hidden)
          expect(fields).not_to include(be_filterable)
        end
      end
    end
  end

  describe "#form_default_value" do
    it "is default_value for new records when value is nil" do
      RailsAdminNext.config Team do
        list do
          field :name do
            default_value "default value"
          end
        end
      end
      @team = Team.new
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }.with(object: @team).form_default_value).to eq("default value")
      @team.name = "set value"
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }.with(object: @team).form_default_value).to be_nil
      @team = FactoryBot.create :team
      @team.name = nil
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }.with(object: @team).form_default_value).to be_nil
    end
  end

  describe "#default_value" do
    it "is nil by default" do
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }.default_value).to be_nil
    end
  end

  describe "#hint" do
    it "is user customizable" do
      RailsAdminNext.config Team do
        list do
          field :division do
            hint "Great Division"
          end
          field :name
        end
      end
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :division }.hint).to eq("Great Division") # custom
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }.hint).to eq("") # default
    end
  end

  describe "#help" do
    it "has a default and be user customizable via i18n" do
      RailsAdminNext.config Team do
        list do
          field :division
          field :name
        end
      end
      field_specific_i18n = RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }
      expect(field_specific_i18n.help).to eq(I18n.translate("admin.help.team.name")) # custom via locales yml
      field_no_specific_i18n = RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :division }
      expect(field_no_specific_i18n.help).to eq(field_no_specific_i18n.generic_help) # rails_admin_next generic fallback
    end
  end

  describe "#css_class" do
    it "has a default and be user customizable" do
      RailsAdminNext.config Team do
        list do
          field :division do
            css_class "custom"
          end
          field :name
        end
      end
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :division }.css_class).to eq("custom") # custom
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :division }.type_css_class).to eq("belongs_to_association_type") # type css class, non-customizable
      expect(RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }.css_class).to eq("name_field") # default
    end
  end

  describe "#associated_collection_cache_all" do
    it "defaults to true if associated collection count < 100" do
      expect(RailsAdminNext.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_truthy
    end

    it "defaults to false if associated collection count >= 100" do
      @players = Array.new(100) do
        FactoryBot.create :player
      end
      expect(RailsAdminNext.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_falsey
    end

    context "with custom configuration" do
      before do
        RailsAdminNext.config.default_associated_collection_limit = 5
      end
      it "defaults to true if associated collection count less than than limit" do
        @players = Array.new(4) do
          FactoryBot.create :player
        end
        expect(RailsAdminNext.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_truthy
      end

      it "defaults to false if associated collection count >= that limit" do
        @players = Array.new(5) do
          FactoryBot.create :player
        end
        expect(RailsAdminNext.config(Team).edit.fields.detect { |f| f.name == :players }.associated_collection_cache_all).to be_falsey
      end
    end
  end

  describe "#searchable_columns" do
    describe "for belongs_to fields" do
      it "finds label method on the opposite side for belongs_to associations by default" do
        expect(RailsAdminNext.config(Team).fields.detect { |f| f.name == :division }.searchable_columns.collect { |c| c[:column] }).to eq(["divisions.name", "teams.division_id"])
      end

      it "searches on opposite table for belongs_to" do
        RailsAdminNext.config(Team) do
          field :division do
            searchable :custom_id
          end
        end
        expect(RailsAdminNext.config(Team).fields.detect { |f| f.name == :division }.searchable_columns.collect { |c| c[:column] }).to eq(["divisions.custom_id"])
      end

      it "searches on asked table with model name" do
        RailsAdminNext.config(Team) do
          field :division do
            searchable League => :name
          end
        end
        expect(RailsAdminNext.config(Team).fields.detect { |f| f.name == :division }.searchable_columns).to eq([{column: "leagues.name", type: :string}])
      end

      it "searches on asked table with table name" do
        RailsAdminNext.config(Team) do
          field :division do
            searchable leagues: :name
          end
        end
        expect(RailsAdminNext.config(Team).fields.detect { |f| f.name == :division }.searchable_columns).to eq([{column: "leagues.name", type: :string}])
      end
    end

    describe "for basic type fields" do
      it "uses base table and find correct column type" do
        expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :text_field }.searchable_columns).to eq([{column: "field_tests.text_field", type: :text}])
        expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :integer_field }.searchable_columns).to eq([{column: "field_tests.integer_field", type: :integer}])
      end

      it "is customizable to another field on the same table" do
        RailsAdminNext.config(FieldTest) do
          field :time_field do
            searchable :date_field
          end
        end
        expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :time_field }.searchable_columns).to eq([{column: "field_tests.date_field", type: :date}])
      end

      it "is customizable to another field on another table with :table_name" do
        RailsAdminNext.config(FieldTest) do
          field :string_field do
            searchable nested_field_tests: :title
          end
        end
        expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :string_field }.searchable_columns).to eq([{column: "nested_field_tests.title", type: :string}])
      end

      it "is customizable to another field on another model with ModelClass" do
        RailsAdminNext.config(FieldTest) do
          field :string_field do
            searchable NestedFieldTest => :title
          end
        end
        expect(RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :string_field }.searchable_columns).to eq([{column: "nested_field_tests.title", type: :string}])
      end
    end
  end

  describe "#searchable and #sortable" do
    it "is false if column is virtual, true otherwise" do
      RailsAdminNext.config League do
        field :virtual_column
        field :name
      end
      @league = FactoryBot.create :league
      expect(RailsAdminNext.config("League").export.fields.detect { |f| f.name == :virtual_column }.sortable).to be_falsey
      expect(RailsAdminNext.config("League").export.fields.detect { |f| f.name == :virtual_column }.searchable).to be_falsey
      expect(RailsAdminNext.config("League").export.fields.detect { |f| f.name == :name }.sortable).to be_truthy
      expect(RailsAdminNext.config("League").export.fields.detect { |f| f.name == :name }.searchable).to be_truthy
    end
  end

  describe "#virtual?" do
    it "is true if column has no properties, false otherwise" do
      RailsAdminNext.config League do
        field :virtual_column
        field :name
      end
      @league = FactoryBot.create :league
      expect(RailsAdminNext.config("League").export.fields.detect { |f| f.name == :virtual_column }.virtual?).to be_truthy
      expect(RailsAdminNext.config("League").export.fields.detect { |f| f.name == :name }.virtual?).to be_falsey
    end
  end

  describe "#default_search_operator" do
    let(:abstract_model) { RailsAdminNext::AbstractModel.new("Player") }
    let(:model_config) { RailsAdminNext.config(abstract_model) }
    let(:queryable_fields) { model_config.list.fields.select(&:queryable?) }

    context "when no search operator is specified for the field" do
      it "uses 'default' search operator" do
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq(RailsAdminNext::Config.default_search_operator)
      end

      it "uses config.default_search_operator if set" do
        RailsAdminNext.config do |config|
          config.default_search_operator = "starts_with"
        end
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq(RailsAdminNext::Config.default_search_operator)
      end
    end

    context "when search operator is specified for the field" do
      it "uses specified search operator" do
        RailsAdminNext.config Player do
          list do
            fields do
              search_operator "starts_with"
            end
          end
        end
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq("starts_with")
      end

      it "uses specified search operator even if config.default_search_operator set" do
        RailsAdminNext.config do |config|
          config.default_search_operator = "starts_with"

          config.model Player do
            list do
              fields do
                search_operator "ends_with"
              end
            end
          end
        end
        expect(queryable_fields.size).to be >= 1
        expect(queryable_fields.first.search_operator).to eq("ends_with")
      end
    end
  end

  describe "#render" do
    it "is configurable" do
      RailsAdminNext.config Team do
        field :name do
          render do
            "rendered"
          end
        end
      end
      expect(RailsAdminNext.config(Team).field(:name).render).to eq("rendered")
    end
  end

  describe "#active" do
    it "is false by default" do
      expect(RailsAdminNext.config(Team).field(:division).active?).to be_falsey
    end
  end

  describe "#visible?" do
    it "is false when fields have specific name " do
      stub_const("FieldVisibilityTest", Class.new(Tableless) do
        column :id, :integer
        column :_id, :integer
        column :_type, :varchar
        column :name, :varchar
        column :created_at, :timestamp
        column :updated_at, :timestamp
        column :deleted_at, :timestamp
        column :created_on, :timestamp
        column :updated_on, :timestamp
        column :deleted_on, :timestamp
      end)
      expect(RailsAdminNext.config(FieldVisibilityTest).base.fields.select(&:visible?).collect(&:name)).to match_array %i[_id created_at created_on deleted_at deleted_on id name updated_at updated_on]
      expect(RailsAdminNext.config(FieldVisibilityTest).list.fields.select(&:visible?).collect(&:name)).to match_array %i[_id created_at created_on deleted_at deleted_on id name updated_at updated_on]
      expect(RailsAdminNext.config(FieldVisibilityTest).edit.fields.select(&:visible?).collect(&:name)).to match_array [:name]
      expect(RailsAdminNext.config(FieldVisibilityTest).show.fields.select(&:visible?).collect(&:name)).to match_array [:name]
    end
  end

  describe "#allowed_methods" do
    it "includes method_name" do
      RailsAdminNext.config do |config|
        config.model Team do
          field :name
        end
      end

      expect(RailsAdminNext.config(Team).field(:name).allowed_methods).to eq [:name]
    end
  end

  describe "#default_filter_operator" do
    it "has a default and be user customizable" do
      RailsAdminNext.config Team do
        list do
          field :division
          field :name do
            default_filter_operator "is"
          end
        end
      end
      name_field = RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :name }
      expect(name_field.default_filter_operator).to eq("is") # custom via user specification
      division_field = RailsAdminNext.config("Team").list.fields.detect { |f| f.name == :division }
      expect(division_field.default_filter_operator).to be nil # rails_admin_next generic fallback
    end
  end

  describe "#eager_load" do
    let(:field) { RailsAdminNext.config("Team").fields.detect { |f| f.name == :players } }

    it "can be set to true" do
      RailsAdminNext.config Team do
        field :players do
          eager_load true
        end
      end
      expect(field.eager_load_values).to eq [:players]
    end

    it "can be set to false" do
      RailsAdminNext.config Team do
        field :players do
          eager_load false
        end
      end
      expect(field.eager_load_values).to eq []
    end

    it "can be set to a custom value" do
      RailsAdminNext.config Team do
        field :players do
          eager_load [{players: :draft}, :fans]
        end
      end
      expect(field.eager_load_values).to eq [{players: :draft}, :fans]
    end
  end
end
