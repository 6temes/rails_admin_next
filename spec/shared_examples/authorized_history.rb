# frozen_string_literal: true

# The policy, stubbed in as PaperTrailTestPolicy, lets an admin list paper trail tests other than
# those named "out of scope"; the user may not list leagues.
RSpec.shared_examples "history within the authorization scope" do |policy|
  let!(:in_scope) { FactoryBot.create(:paper_trail_test, name: "in scope", created_at: 3.days.ago) }
  let!(:out_of_scope) { FactoryBot.create(:paper_trail_test, name: "out of scope") }

  before do
    stub_const("PaperTrailTestPolicy", policy)
    RailsAdminNext.config { it.audit_with :paper_trail, "User", "PaperTrail::Version" }
    deleted = FactoryBot.create(:paper_trail_test, name: "deleted")
    PaperTrail::Version.create!(item: in_scope, event: "in-scope-change")
    PaperTrail::Version.create!(item: out_of_scope, event: "out-of-scope-change")
    PaperTrail::Version.create!(item: FactoryBot.create(:league), event: "league-change")
    PaperTrail::Version.create!(item: deleted, event: "deleted-record-change")
    deleted.delete
  end

  it "shows on the dashboard only changes to records the user may list", :aggregate_failures do
    visit dashboard_path

    is_expected.to have_content("in-scope-change")
    is_expected.not_to have_content("out-of-scope-change")
    is_expected.not_to have_content("league-change")
    is_expected.not_to have_content("deleted-record-change")
  end

  it "shows on the dashboard no changes to a versioned model the user may not list" do
    stub_const("PaperTrailTestPolicy", Class.new(policy) { def index? = false })

    visit dashboard_path

    is_expected.not_to have_content("in-scope-change")
  end

  it "shows on a model's history only changes to records in the user's scope", :aggregate_failures do
    visit history_index_path(model_name: "paper_trail_test")

    is_expected.to have_content("in-scope-change")
    is_expected.not_to have_content("out-of-scope-change")
    is_expected.not_to have_content("deleted-record-change")
  end

  it "dates a model's last created record from within the user's scope" do
    visit dashboard_path

    expect(find(".paper_trail_test_links td:nth-child(2)")).to have_content("3 days ago")
  end
end
