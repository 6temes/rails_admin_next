# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PolymorphicAssociation field", type: :request do
  subject { page }

  context "on create" do
    it "is editable", js: true do
      @players = ["Jackie Robinson", "Rob Wooten"].map { |name| FactoryBot.create :player, name: name }
      visit new_path(model_name: "comment")
      select "Player", from: "comment[commentable_type]"
      find("input.ra-filtering-select-input").set("Rob")
      expect(page).to have_selector('[role="option"]')
      find('[role="option"]', text: "Jackie Robinson").click
      click_button "Save"
      is_expected.to have_content "Comment successfully created"
      expect(Comment.first.commentable).to eq @players[0]
    end

    it "uses base class for models with inheritance" do
      @hardball = FactoryBot.create :hardball
      post new_path(model_name: "comment", comment: {commentable_type: "Hardball", commentable_id: @hardball.id})
      @comment = Comment.first
      expect(@comment.commentable_type).to eq "Ball"
      expect(@comment.commentable).to eq @hardball
    end

    it "clears the selected id on type change", js: true do
      @players = ["Jackie Robinson", "Rob Wooten"].map { |name| FactoryBot.create :player, name: name }
      visit new_path(model_name: "comment")
      select "Player", from: "comment[commentable_type]"
      find("input.ra-filtering-select-input").set("Rob")
      expect(page).to have_selector('[role="option"]')
      find('[role="option"]', text: "Jackie Robinson").click
      select "Team", from: "comment[commentable_type]"
      expect(find("#comment_commentable_id", visible: false).value).to eq ""
    end

    it "closes the rebuilt widget on outside click after a type switch", js: true do
      # Regression test for a leaked document click listener: each type switch
      # reloads the filtering-select widget (tears down and rebuilds its DOM +
      # outside-click handler). Switching twice exercises reload() more than
      # once so a listener left over from a prior build would pile up; with
      # js_errors: true any exception thrown from a stale handler fails the spec.
      @team = FactoryBot.create :team, name: "Los Angeles Dodgers"
      @players = ["Jackie Robinson", "Rob Wooten"].map { |name| FactoryBot.create :player, name: name }
      visit new_path(model_name: "comment")
      select "Player", from: "comment[commentable_type]"
      select "Team", from: "comment[commentable_type]"
      find("input.ra-filtering-select-input").set("Los")
      expect(page).to have_selector('[role="option"]', text: "Los Angeles Dodgers")
      find("h1").click
      expect(page).to have_no_selector('[role="option"]')
    end

    context "when the associated model is declared in a two-level namespace" do
      it "successfully saves the record", js: true do
        polymorphic_association_tests = ["Jackie Robinson", "Rob Wooten"].map do |name|
          FactoryBot.create(:two_level_namespaced_polymorphic_association_test, name: name)
        end

        visit new_path(model_name: "comment")

        select "Polymorphic association test", from: "comment[commentable_type]"
        find("input.ra-filtering-select-input").set("Rob")

        expect(page).to have_selector('[role="option"]')

        find('[role="option"]', text: "Jackie Robinson").click
        click_button "Save"
        is_expected.to have_content "Comment successfully created"
        expect(Comment.first.commentable).to eq polymorphic_association_tests.first
      end
    end
  end

  context "on update" do
    let(:team) { FactoryBot.create :team, name: "Los Angeles Dodgers" }
    let(:comment) { FactoryBot.create :comment, commentable: team }
    let!(:players) { ["Jackie Robinson", "Rob Wooten", "Scott Hairston"].map { |name| FactoryBot.create :player, name: name } }

    it "is editable", js: true do
      visit edit_path(model_name: "comment", id: comment.id)
      expect(find("select#comment_commentable_type").value).to eq "Team"
      expect(find("select#comment_commentable_id", visible: false).value).to eq team.id.to_s
      find("input.ra-filtering-select-input").set("Los")
      expect(page).to have_selector('[role="option"]')
      expect(all('[role="option"]').map(&:text)).to eq ["Los Angeles Dodgers"]
      select "Player", from: "comment[commentable_type]"
      find("input.ra-filtering-select-input").set("Rob")
      expect(page).to have_selector('[role="option"]')
      expect(all('[role="option"]').map(&:text)).to eq ["Rob Wooten", "Jackie Robinson"]
      find('[role="option"]', text: "Jackie Robinson").click
      click_button "Save"
      is_expected.to have_content "Comment successfully updated"
      expect(comment.reload.commentable).to eq players[0]
    end

    it "is visible in the owning end" do
      visit edit_path(model_name: "team", id: team.id)

      is_expected.to have_selector("select#team_comment_ids")
    end

    context "with records in different models share the same id", js: true do
      let!(:players) { [FactoryBot.create(:player, id: team.id, name: "Jackie Robinson")] }

      it "clears the selected id on type change", js: true do
        visit edit_path(model_name: "comment", id: comment.id)
        select "Player", from: "comment[commentable_type]"
        click_button "Save"
        is_expected.to have_content "Comment successfully updated"
        expect(comment.reload.commentable).to eq nil
      end

      it "updates correctly", js: true do
        visit edit_path(model_name: "comment", id: comment.id)
        select "Player", from: "comment[commentable_type]"
        find("input.ra-filtering-select-input").set("Rob")
        expect(page).to have_selector('[role="option"]')
        find('[role="option"]', text: "Jackie Robinson").click
        click_button "Save"
        is_expected.to have_content "Comment successfully updated"
        expect(comment.reload.commentable).to eq players[0]
      end
    end
  end

  context "on show" do
    before do
      @player = FactoryBot.create :player
      @comment = FactoryBot.create :comment, commentable: @player
      visit show_path(model_name: "comment", id: @comment.id)
    end

    it "shows associated object" do
      is_expected.to have_css("a[href='/admin/player/#{@player.id}']")
    end
  end

  context "on list" do
    before :each do
      @team = FactoryBot.create :team
      @comment = FactoryBot.create :comment, commentable: @team
    end

    it "works like belongs to associations in the list view" do
      visit index_path(model_name: "comment")

      is_expected.to have_content(@team.name)
    end
  end
end
