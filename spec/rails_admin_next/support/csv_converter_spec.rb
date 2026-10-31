# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::CSVConverter do
  it "keeps headers ordering" do
    RailsAdminNext.config(Player) do
      export do
        field :number
        field :name
      end
    end

    FactoryBot.create :player
    objects = Player.all
    schema = {only: %i[number name]}
    expect(RailsAdminNext::CSVConverter.new(objects, schema).to_csv({})[2]).to match(/Number,Name/)
  end

  describe "#generate_csv_header" do
    let(:objects) { FactoryBot.create_list :player, 1 }
    before do
      RailsAdminNext.config(Player) do
        export do
          field :number
          field :name
        end
      end
    end

    it "does not break when non-existent fields are given" do
      expect(RailsAdminNext::CSVConverter.new(objects, {only: %i[name foo], include: {bar: :baz}}).send(:generate_csv_header))
        .to eq ["Name"]
    end

    it "does not break when non-association fields are given to :include" do
      expect(RailsAdminNext::CSVConverter.new(objects, {only: %i[name foo], include: {name: :name}}).send(:generate_csv_header))
        .to eq ["Name"]
    end
  end

  describe "#to_csv" do
    before do
      RailsAdminNext.config(Player) do
        export do
          field :number
          field :name
        end
      end
    end

    let(:objects) { FactoryBot.create_list :player, 1, number: 1, name: "なまえ" }
    let(:schema) { {only: %i[number name]} }
    let(:options) { {encoding_to: encoding} }

    subject { RailsAdminNext::CSVConverter.new(objects, schema).to_csv(options) }

    context "when encoding FROM latin1", active_record: true do
      let(:connection_config) do
        if ActiveRecord::Base.respond_to?(:connection_db_config)
          ActiveRecord::Base.connection_db_config.configuration_hash
        else
          ActiveRecord::Base.connection_config
        end
      end
      let(:encoding) { "" }
      let(:objects) { FactoryBot.create_list :player, 1, number: 1, name: "Josè".encode("ISO-8859-1") }
      before do
        case connection_config[:adapter]
        when "postgresql"
          @connection = ActiveRecord::Base.connection.raw_connection
          @connection.set_client_encoding("latin1")
        when "mysql2"
          ActiveRecord::Base.connection.execute("SET NAMES latin1;")
        end
      end
      after do
        case connection_config[:adapter]
        when "postgresql"
          @connection.set_client_encoding("utf8")
        when "mysql2"
          ActiveRecord::Base.connection.execute("SET NAMES utf8;")
        end
      end

      it "exports to ISO-8859-1" do
        expect(subject[1]).to eq "ISO-8859-1"
        expect(subject[2].encoding).to eq Encoding::ISO_8859_1
        expect(subject[2].unpack1("H*"))
          .to eq "4e756d6265722c4e616d650a312c4a6f73e80a"
      end
    end

    context "when encoding to UTF-8" do
      let(:encoding) { "UTF-8" }

      it "exports to UTF-8 with BOM" do
        expect(subject[1]).to eq "UTF-8"
        expect(subject[2].encoding).to eq Encoding::UTF_8
        expect(subject[2].unpack1("H*"))
          .to eq "efbbbf4e756d6265722c4e616d650a312ce381aae381bee381880a" # have BOM
      end
    end

    context "when encoding to Shift_JIS" do
      let(:encoding) { "Shift_JIS" }

      it "exports to Shift_JIS" do
        expect(subject[1]).to eq "Shift_JIS"
        expect(subject[2].encoding).to eq Encoding::Shift_JIS
        expect(subject[2].unpack1("H*"))
          .to eq "4e756d6265722c4e616d650a312c82c882dc82a60a"
      end
    end

    context "when encoding to UTF-16(ASCII-incompatible)" do
      let(:encoding) { "UTF-16" }

      it "encodes to expected byte sequence" do
        expect(subject[1]).to eq "UTF-16"
        expect(subject[2].encoding).to eq Encoding::UTF_16
        expect(subject[2].unpack1("H*").force_encoding("US-ASCII"))
          .to eq "feff004e0075006d006200650072002c004e0061006d0065000a0031002c306a307e3048000a"
      end
    end

    context "when specifying a column separator" do
      context "when options keys are symbolized" do
        let(:options) { {encoding_to: "UTF-8", generator: {col_sep: "___"}} }
        it "uses the column separator specified" do
          expect(subject[2].unpack1("H*"))
            .to eq "efbbbf4e756d6265725f5f5f4e616d650a315f5f5fe381aae381bee381880a"
        end
      end

      context "when options keys are string" do
        let(:options) { {"encoding_to" => "UTF-8", "generator" => {"col_sep" => "___"}} }
        it "uses the column separator specified" do
          expect(subject[2].unpack1("H*"))
            .to eq "efbbbf4e756d6265725f5f5f4e616d650a315f5f5fe381aae381bee381880a"
        end
      end
    end

    context "when objects is empty" do
      let(:objects) { [] }
      let(:options) { {} }

      it "generates an empty csv" do
        expect(subject[2]).to eq("\n")
      end
    end
  end

  describe "walking a relation" do
    before do
      RailsAdminNext.config(Player) do
        export do
          field :number
          field :name
        end
      end
      stub_const("RailsAdminNext::CSVConverter::BATCH_SIZE", 2)
    end

    let(:schema) { {only: %i[number name]} }
    let(:pk_sort) { "#{Player.quoted_table_name}.#{Player.connection.quote_column_name("id")} desc" }

    def data_rows(objects, schema)
      CSV.parse(RailsAdminNext::CSVConverter.new(objects, schema).to_csv({})[2]).drop(1)
    end

    it "keeps a column sort across batches" do
      %w[Charlie Alice Echo Bob Delta].each { FactoryBot.create :player, name: it }

      expect(data_rows(Player.order(:name), schema).map(&:last)).to eq %w[Alice Bob Charlie Delta Echo]
    end

    it "keeps a descending primary-key sort without discarding the scoped order" do
      players = FactoryBot.create_list :player, 5
      ActiveRecord.error_on_ignored_order = true

      expect(data_rows(Player.reorder(pk_sort), schema).map(&:first)).to eq players.map(&:number).reverse.map(&:to_s)
    ensure
      ActiveRecord.error_on_ignored_order = false
    end

    it "keeps an unqualified primary-key sort" do
      players = FactoryBot.create_list :player, 5

      expect(data_rows(Player.reorder("id desc"), schema).map(&:first)).to eq players.map(&:number).reverse.map(&:to_s)
    end

    it "keeps a sort on an eager-loaded association's column" do
      %w[Echo Bravo Delta Alpha Charlie].each { FactoryBot.create :player, name: "#{it} player", team: FactoryBot.create(:team, name: it) }
      sort = "#{Team.quoted_table_name}.#{Team.connection.quote_column_name("name")} asc"

      expect(data_rows(Player.includes(:team, :comments).reorder(sort), schema).map(&:last))
        .to eq ["Alpha player", "Bravo player", "Charlie player", "Delta player", "Echo player"]
    end

    it "keeps a limited relation's bound" do
      %w[Charlie Alice Echo Bob Delta].each { FactoryBot.create :player, name: it }

      expect(data_rows(Player.order(:name).limit(3), schema).map(&:last)).to eq %w[Alice Bob Charlie]
    end

    it "exports every record when sorting on a has-many association's column" do
      players = FactoryBot.create_list :player, 5
      players.each_with_index do |player, i|
        FactoryBot.create :comment, commentable: player, created_at: (2 * i).days.ago
        FactoryBot.create :comment, commentable: player, created_at: (2 * i + 1).days.ago
      end
      sort = "#{Comment.quoted_table_name}.#{Comment.connection.quote_column_name("created_at")} asc"

      expect(data_rows(Player.includes(:comments).reorder(sort), schema).map(&:last).uniq).to match_array players.map(&:name)
    end

    it "does not load the relation" do
      FactoryBot.create_list :player, 3
      objects = Player.all
      RailsAdminNext::CSVConverter.new(objects, schema).to_csv({})

      expect(objects).not_to be_loaded
    end

    it "writes the header for an empty relation" do
      expect(RailsAdminNext::CSVConverter.new(Player.all, schema).to_csv({})[2]).to eq "Number,Name\n"
    end

    it "keeps the sort for a composite primary key", composite_primary_keys: true do
      RailsAdminNext.config(Fanship) do
        export do
          field :since
        end
      end
      fanships = [Date.new(2024, 3, 1), Date.new(2024, 2, 1), Date.new(2024, 1, 1)].map { FactoryBot.create :fanship, since: it }
      since = RailsAdminNext.config(Fanship).export.fields.detect { it.name == :since }
      expected = fanships.reverse.map { since.with(object: it).export_value }

      expect(data_rows(Fanship.order(:since), {only: %i[since]}).flatten).to eq expected
    end
  end
end
