# The including spec stubs a PaperTrailTest policy whose scope resolves to something other than
# a relation, and signs in an admin.
RSpec.shared_examples "history under an authorization scope that is not a relation" do
  before do
    RailsAdminNext.config { it.audit_with :paper_trail, "User", "PaperTrail::Version" }
    PaperTrail::Version.create!(item: FactoryBot.create(:paper_trail_test, created_at: 3.days.ago), event: "hidden-change")
  end

  it "shows no changes on the dashboard" do
    visit dashboard_path

    is_expected.not_to have_content("hidden-change")
  end

  it "shows no changes on a model's history" do
    visit history_index_path(model_name: "paper_trail_test")

    is_expected.not_to have_content("hidden-change")
  end

  it "dates no last created record on the dashboard" do
    visit dashboard_path

    expect(find(".paper_trail_test_links td:nth-child(2)")).not_to have_content("ago")
  end
end
