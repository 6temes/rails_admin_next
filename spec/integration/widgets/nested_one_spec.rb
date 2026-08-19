# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Nested one widget", type: :request, js: true do
  subject { page }

  let(:field_test) { FactoryBot.create :field_test }
  before do
    RailsAdminNext.config(FieldTest) do
      field :comment
    end
  end

  it "adds a nested item" do
    visit edit_path(model_name: "field_test", id: field_test.id)

    find("#field_test_comment_attributes_field .add_nested_fields").click
    fill_in "field_test_comment_attributes_content", with: "nested comment content"

    # trigger click via JS, workaround for instability in CI
    execute_script %(document.querySelector('button[name="_save"]').click())
    is_expected.to have_content("Field test successfully updated")

    expect(field_test.reload.comment.content.strip).to eq("nested comment content")
  end

  it "edits a persisted nested item in place", js: false do
    comment = FactoryBot.create :comment, commentable: field_test
    visit edit_path(model_name: "field_test", id: field_test.id)

    fill_in "field_test_comment_attributes_content", with: "nested comment content edited"
    click_button "Save"
    is_expected.to have_content("Field test successfully updated")

    expect(field_test.reload.comment.content.strip).to eq("nested comment content edited")
    # A replacement child would satisfy the content assertion too. The id is what proves
    # the hand-rendered hidden id round-tripped, so Rails updated instead of rebuilding.
    expect(field_test.comment.id).to eq comment.id
    expect(Comment.count).to eq 1
  end

  it "hides the add control once a subform is present" do
    visit edit_path(model_name: "field_test", id: field_test.id)
    within "#field_test_comment_attributes_field" do
      find(".add_nested_fields").click
      expect(page).to have_no_selector(".add_nested_fields", visible: true)
    end
  end

  it "keeps the add control hidden while a subform is marked for destruction" do
    FactoryBot.create :comment, commentable: field_test
    visit edit_path(model_name: "field_test", id: field_test.id)
    within "#field_test_comment_attributes_field" do
      expect(page).to have_no_selector(".add_nested_fields", visible: true)
      find("[data-nested-form-target='subform'] .remove_nested_fields", visible: :all).click
      expect(page).to have_selector("[data-nested-form-target='subform'].marked_for_destruction")
      # Still hidden: singular fields_for renders unindexed names, so a fresh
      # replacement alongside the marked subform would post colliding
      # attributes and mutate the record instead of destroy+create.
      expect(page).to have_no_selector(".add_nested_fields", visible: true)
      find("[data-nested-form-target='subform'] .remove_nested_fields", visible: :all).click
      expect(page).to have_no_selector("[data-nested-form-target='subform'].marked_for_destruction")
      expect(page).to have_no_selector(".add_nested_fields", visible: true)
    end
  end

  it "marks a persisted item for destruction and destroys it only on save" do
    FactoryBot.create :comment, commentable: field_test
    visit edit_path(model_name: "field_test", id: field_test.id)

    within(find("#field_test_comment_attributes_field [data-nested-form-target='subform']")) { find(".remove_nested_fields", visible: :all).click }
    expect(page).to have_selector("[data-nested-form-target='subform'].marked_for_destruction")
    # The add control must NOT reshow while marked (replace-before-save would
    # post colliding singular attributes); destroy first, then add.
    expect(page).to have_no_selector("#field_test_comment_attributes_field .add_nested_fields", visible: true)

    # trigger click via JS, workaround for instability in CI
    execute_script %(document.querySelector('button[name="_save"]').click())
    is_expected.to have_content("Field test successfully updated")

    expect(field_test.reload.comment).to be nil
  end

  it "is optional" do
    visit edit_path(model_name: "field_test", id: field_test.id)
    click_button "Save"
    expect(field_test.reload.comment).to be_nil
  end

  it "removes an unsaved subform from the DOM and restores the add control" do
    visit new_path(model_name: "field_test")
    within "#field_test_comment_attributes_field" do
      find(".add_nested_fields").click
      expect(page).to have_selector("[data-nested-form-target='subform']")
      within("[data-nested-form-target='subform']") { find(".remove_nested_fields", visible: :all).click }
      expect(page).to have_no_selector("[data-nested-form-target='subform']")
      expect(page).to have_selector(".add_nested_fields", visible: true)
    end
  end

  context "when XSS attack is attempted" do
    it "does not break on adding a new item" do
      allow(I18n).to receive(:t).and_call_original
      expect(I18n).to receive(:t).with("admin.form.new_model", name: "Comment").and_return('<script>throw "XSS";</script>')
      visit edit_path(model_name: "field_test", id: field_test.id)
      find("#field_test_comment_attributes_field .add_nested_fields").click
    end

    it "does not break on adding an existing item" do
      RailsAdminNext.config Comment do
        object_label_method :content
      end
      FactoryBot.create :comment, content: '<script>throw "XSS";</script>', commentable: field_test
      visit edit_path(model_name: "field_test", id: field_test.id)
    end
  end

  context "when the child points back at the record being edited" do
    it "hides the polymorphic back-reference on an existing subform", js: false do
      FactoryBot.create :comment, commentable: field_test
      visit edit_path(model_name: "field_test", id: field_test.id)

      expect(page.body).to include("field_test_comment_attributes_content")
      expect(page.body).not_to include("field_test_comment_attributes_commentable_type")
      expect(page.body).not_to include("field_test_comment_attributes_commentable_id")
    end

    it "hides it in the blank template too", js: false do
      visit new_path(model_name: "field_test")

      expect(page.body).to include("field_test_comment_attributes_content")
      expect(page.body).not_to include("field_test_comment_attributes_commentable_type")
      expect(page.body).not_to include("field_test_comment_attributes_commentable_id")
    end

    context "when neither side of the pair declares inverse_of" do
      let(:team) { FactoryBot.create :team }
      let(:nested_player) { NestedPlayer.create! name: "Sluggo", number: 42 }
      before do
        RailsAdminNext.config(NestedPlayer) do
          field :name
          field :draft
        end
        Draft.create! player: nested_player, team: team, date: Date.new(2020, 1, 23), round: 1, pick: 1, overall: 1
      end

      # Draft#player is a required belongs_to, so leaving it rendered marks a field only
      # the nested save can fill, and the browser refuses to submit the form.
      it "hides the child's required back-reference and keeps its other association", js: false do
        visit edit_path(model_name: "nested_player", id: nested_player.id)

        expect(page.body).to include("nested_player_draft_attributes_college")
        expect(page.body).to include("nested_player_draft_attributes_team_id")
        expect(page.body).not_to include("nested_player_draft_attributes_player_id")
      end

      # The back-reference never round-trips through the form, so the save depends on
      # Rails wiring the inverse in memory.
      it "still saves the subform, with the link back intact", js: false do
        draft_id = nested_player.draft.id
        visit edit_path(model_name: "nested_player", id: nested_player.id)
        fill_in "nested_player_draft_attributes_college", with: "Riverside"
        click_button "Save"

        expect(nested_player.reload.draft.college).to eq "Riverside"
        expect(nested_player.draft.player_id).to eq nested_player.id
        # dependent: :destroy would clean up an orphan, so a replacement child leaves the
        # count alone and only the id shows it.
        expect(nested_player.draft.id).to eq draft_id
      end
    end
  end

  context "when the nested field contains a required field" do
    before do
      RailsAdminNext.config Comment do
        configure :content do
          required true
        end
      end
    end

    it "is not blocked by required validation when marked for destruction" do
      FactoryBot.create :comment, commentable: field_test, content: ""
      visit edit_path(model_name: "field_test", id: field_test.id)

      within(find("#field_test_comment_attributes_field [data-nested-form-target='subform']")) { find(".remove_nested_fields", visible: :all).click }

      # trigger click via JS, workaround for instability in CI
      execute_script %(document.querySelector('button[name="_save"]').click())
      is_expected.to have_content("Field test successfully updated")

      expect(field_test.reload.comment).to be nil
    end
  end
end
