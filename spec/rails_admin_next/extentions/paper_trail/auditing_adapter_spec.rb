# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Extensions::PaperTrail::AuditingAdapter, active_record: true do
  let(:controller) { double(set_paper_trail_whodunnit: nil) }

  describe "#initialize" do
    it "accepts the user and version classes as arguments" do
      adapter = described_class.new(controller, User::Confirmed, Trail)
      expect(adapter.user_class).to eq User::Confirmed
      expect(adapter.version_class).to eq Trail
    end

    it "supports block DSL" do
      adapter = described_class.new(controller) do
        user_class User::Confirmed
        version_class Trail
        sort_by(created_at: :asc)
      end
      expect(adapter.user_class).to eq User::Confirmed
      expect(adapter.version_class).to eq Trail
      expect(adapter.sort_by).to eq({created_at: :asc})
    end
  end

  describe "#latest" do
    subject(:adapter) { described_class.new(nil, "User", "PaperTrail::Version") }

    let(:model) { RailsAdminNext::AbstractModel.new(PaperTrailTest) }
    let!(:kept) { PaperTrail::Version.create!(item: FactoryBot.create(:paper_trail_test, name: "kept"), event: "kept") }
    let!(:dropped) { PaperTrail::Version.create!(item: FactoryBot.create(:paper_trail_test, name: "dropped"), event: "dropped") }

    it "lists every version without scopes" do
      expect(adapter.latest.map(&:message)).to contain_exactly("kept", "dropped")
    end

    it "lists only versions whose item is in its model's scope, through a subquery", :aggregate_failures do
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] }
      versions = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        adapter.latest(scopes: {model => PaperTrailTest.where(name: "kept")})
      end

      expect(versions.map(&:message)).to eq ["kept"]
      expect(queries.first).to match(/FROM "versions" .*IN \(SELECT "paper_trail_tests"\."id" FROM "paper_trail_tests"/i)
    end

    it "lists nothing for no scopes" do
      expect(adapter.latest(scopes: {})).to be_empty
    end

    it "matches a subclass's versions by its base class" do
      subclass = RailsAdminNext::AbstractModel.new(PaperTrailTestSubclass)
      expect(adapter.latest(scopes: {subclass => PaperTrailTestSubclass.where(name: "kept")}).map(&:message)).to eq ["kept"]
    end
  end

  describe "#listing_for_model" do
    subject { RailsAdminNext::Extensions::PaperTrail::AuditingAdapter.new(nil) }
    let(:model) { RailsAdminNext::AbstractModel.new(PaperTrailTest) }

    it "uses the given sort order" do
      expect_any_instance_of(ActiveRecord::Relation).to receive(:reorder).with(whodunnit: :asc).and_call_original
      subject.listing_for_model model, nil, :username, false, true, nil, 20
    end

    it "uses the default order when sort is not given" do
      expect_any_instance_of(ActiveRecord::Relation).to receive(:reorder).with(id: :desc).and_call_original
      subject.listing_for_model model, nil, false, false, true, nil, 20
    end
    it "lists only versions whose item is in the given scope" do
      PaperTrail::Version.create!(item: FactoryBot.create(:paper_trail_test, name: "kept"), event: "kept")
      PaperTrail::Version.create!(item: FactoryBot.create(:paper_trail_test, name: "dropped"), event: "dropped")

      listing = subject.listing_for_model model, nil, false, false, true, nil, 20, scope: PaperTrailTest.where(name: "kept")
      expect(listing.map(&:message)).to eq ["kept"]
    end
  end
end
