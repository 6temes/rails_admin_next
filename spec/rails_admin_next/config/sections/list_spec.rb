# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Sections::List do
  describe "#fields_for_table" do
    subject { RailsAdminNext.config(Player).list }

    it "brings sticky fields first" do
      RailsAdminNext.config Player do
        list do
          field(:number)
          field(:id)
          field(:name) { sticky true }
        end
      end
      expect(subject.fields_for_table.map(&:name)).to eq %i[name number id]
    end

    it "keep the original order except for stickey ones" do
      RailsAdminNext.config Player do
        list do
          configure(:number) { sticky true }
        end
      end
      expect(subject.fields_for_table.map(&:name)).to eq %i[number] + (subject.visible_fields.map(&:name) - %i[number])
    end
  end

  describe "#pagination" do
    it "is infinite unless configured" do
      expect(RailsAdminNext.config(Player).list.pagination).to eq :infinite
      expect(RailsAdminNext.config(Player).list.numbered_pagination?).to be false
    end

    it "can be set to numbered for one model only" do
      RailsAdminNext.config Player do
        list { pagination :numbered }
      end
      expect(RailsAdminNext.config(Player).list.pagination).to eq :numbered
      expect(RailsAdminNext.config(Player).list.numbered_pagination?).to be true
      expect(RailsAdminNext.config(Team).list.pagination).to eq :infinite
    end

    it "raises naming both valid values for anything else" do
      RailsAdminNext.config Player do
        list { pagination :endless }
      end
      expect { RailsAdminNext.config(Player).list.numbered_pagination? }
        .to raise_error ArgumentError, /:infinite or :numbered/
    end
  end
end
