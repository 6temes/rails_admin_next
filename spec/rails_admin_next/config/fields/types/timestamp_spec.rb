# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::Timestamp, active_record: true do
  it_behaves_like "a generic field type", :timestamp_field, :timestamp

  describe "#parse_input" do
    before :each do
      @object = FactoryBot.create(:field_test)
      @time = ::Time.now.getutc
      @field = RailsAdminNext.config(FieldTest).fields.detect { |f| f.name == :timestamp_field }
    end

    after :each do
      Time.zone = "UTC"
    end

    it "reads %B %d, %Y %H:%M" do
      @object.timestamp_field = @field.parse_input(timestamp_field: @time.strftime("%B %d, %Y %H:%M"))
      expect(@object.timestamp_field.strftime("%Y-%m-%d %H:%M")).to eq(@time.strftime("%Y-%m-%d %H:%M"))
    end
  end

  describe "a PostgreSQL timestamptz column" do
    let(:activerecord_config) { ::ActiveRecord::Base.connection_db_config.configuration_hash }

    it "configures as a timestamp field and filters", :aggregate_failures do
      if %w[postgresql postgis].include?(activerecord_config[:adapter])
        ActiveRecord::Base.connection.create_table(:timestamptz_tests) { |t| t.timestamptz :at }
        stub_const("TimestamptzTest", Class.new(ActiveRecord::Base) { self.table_name = "timestamptz_tests" })
        today = TimestamptzTest.create!(at: Time.current)
        TimestamptzTest.create!(at: 3.days.ago)

        expect(RailsAdminNext.config(TimestamptzTest).fields.detect { |f| f.name == :at }.type).to eq(:timestamp)
        expect(RailsAdminNext::AbstractModel.new(TimestamptzTest).all(filters: {"at" => {"0000" => {o: "today"}}}))
          .to eq([today])
      end
    end
  end
end
