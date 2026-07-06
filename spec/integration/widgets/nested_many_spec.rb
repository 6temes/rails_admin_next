# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Nested many widget", type: :request, js: true do
  subject { page }

  let(:field_test) { FactoryBot.create :field_test }
  let(:nested_field_tests) { %w[1 2].map { |i| NestedFieldTest.create! title: "title #{i}", field_test: field_test } }
  before do
    RailsAdminNext.config(FieldTest) do
      field :nested_field_tests
    end
  end

  it "adds a new nested item and focuses its first field" do
    visit edit_path(model_name: "field_test", id: field_test.id)

    within "#field_test_nested_field_tests_attributes_field" do
      find(".add_nested_fields").click
      expect(page).to have_selector("[data-nested-form-target='subform']")
    end
    # Focus lands inside the new subform, never on a hidden id/_destroy input.
    expect(page.evaluate_script("document.activeElement.closest(\"[data-nested-form-target='subform']\") !== null")).to be true
    expect(page.evaluate_script("document.activeElement.type")).not_to eq("hidden")

    find("input[name$='[title]']").set("brand new nested title")

    # trigger click via JS, workaround for instability in CI
    execute_script %(document.querySelector('button[name="_save"]').click())
    is_expected.to have_content("Field test successfully updated")

    expect(field_test.nested_field_tests.length).to eq(1)
    expect(field_test.nested_field_tests.first.title).to eq("brand new nested title")
  end

  it "edits a nested item" do
    nested_field_tests
    visit edit_path(model_name: "field_test", id: field_test.id)

    fill_in "field_test_nested_field_tests_attributes_0_title", with: "nested field test title 1 edited"
    edited_id = find("#field_test_nested_field_tests_attributes_0_id", visible: false).value

    # trigger click via JS, workaround for instability in CI
    execute_script %(document.querySelector('button[name="_save"]').click())
    is_expected.to have_content("Field test successfully updated")

    expect(field_test.nested_field_tests.find(edited_id).title).to eq("nested field test title 1 edited")
  end

  it "marks a persisted item for destruction and destroys it only on save" do
    nested_field_tests
    visit edit_path(model_name: "field_test", id: field_test.id)

    within(find("[data-nested-form-target='subform']", match: :first)) { find(".remove_nested_fields", visible: :all).click }

    expect(page).to have_selector("[data-nested-form-target='subform'].marked_for_destruction")
    expect(find("#field_test_nested_field_tests_attributes_0__destroy", visible: false).value).to eq("1")

    # trigger click via JS, workaround for instability in CI
    execute_script %(document.querySelector('button[name="_save"]').click())
    is_expected.to have_content("Field test successfully updated")

    expect(field_test.reload.nested_field_tests.map(&:id)).to eq [nested_field_tests[1].id]
  end

  it "removes an unsaved subform from the DOM" do
    visit new_path(model_name: "field_test")
    within "#field_test_nested_field_tests_attributes_field" do
      find(".add_nested_fields").click
      expect(page).to have_selector("[data-nested-form-target='subform']")
      within("[data-nested-form-target='subform']") { find(".remove_nested_fields", visible: :all).click }
      expect(page).to have_no_selector("[data-nested-form-target='subform']")
    end
  end

  it "keeps subforms intact and focuses the first invalid field after a failed save" do
    RailsAdminNext.config(FieldTest) do
      field :string_field
      field :nested_field_tests
    end
    visit new_path(model_name: "field_test")
    within "#field_test_nested_field_tests_attributes_field" do
      find(".add_nested_fields").click
      find("input[name$='[title]']").set("survives the error")
    end
    # `Invalid` trips FieldTest's exclusion validation, so the save fails and the
    # form re-renders.
    fill_in "field_test[string_field]", with: "Invalid"
    execute_script %(document.querySelector('button[name="_save"]').click())

    expect(page).to have_selector(".control-group.error #field_test_string_field")
    # The nested subform the user added is still present with its value...
    expect(find("input[name$='[title]']").value).to eq("survives the error")
    # ...and focus has moved to the first invalid field, flagged aria-invalid.
    expect(page.evaluate_script("document.activeElement.id")).to eq("field_test_string_field")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-invalid')")).to eq("true")
  end

  it "sets bindings[:object] to nested object", js: false do
    RailsAdminNext.config(NestedFieldTest) do
      nested do
        field :title do
          label do
            bindings[:object].class.name
          end
        end
      end
    end
    nested_field_tests
    visit edit_path(model_name: "field_test", id: field_test.id)
    expect(find("#field_test_nested_field_tests_attributes_0_title_field")).to have_content("NestedFieldTest")
  end

  it "is deactivatable" do
    visit new_path(model_name: "field_test")
    is_expected.to have_selector("#field_test_nested_field_tests_attributes_field .add_nested_fields")
    RailsAdminNext.config(FieldTest) do
      configure :nested_field_tests do
        nested_form false
      end
    end
    visit new_path(model_name: "field_test")
    is_expected.to have_no_selector("#field_test_nested_field_tests_attributes_field .add_nested_fields")
  end

  context "with nested_attributes_options given" do
    before do
      allow(FieldTest.nested_attributes_options).to receive(:[]).with(any_args)
        .and_return(allow_destroy: true)
    end

    it "does not show a destroy button on persisted records (only in the blank template) when :allow_destroy is false", js: false do
      nested_field_tests
      allow(FieldTest.nested_attributes_options).to receive(:[]).with(:nested_field_tests)
        .and_return(allow_destroy: false)
      visit edit_path(model_name: "field_test", id: field_test.id)
      expect(find("#field_test_nested_field_tests_attributes_0_title").value).to eq("title 1")
      # Persisted records carry no destroy control, but the blank <template> does.
      is_expected.not_to have_selector("[data-nested-form-target='container'] .remove_nested_fields")
      expect(page.body).to match(%r{<template[^>]*>.*remove_nested_fields.*</template>}m)
    end
  end

  context "when a field which have the same name of nested_in field's" do
    it "does not hide fields which are not associated with nesting parent field's model", js: false do
      visit new_path(model_name: "field_test")
      # The blank-row names only exist inside the <template>, so matching the
      # whole response body is unambiguous here.
      expect(page.body).not_to match(/id="field_test_nested_field_tests_attributes_new_nested_field_tests_field_test_id"/)
      expect(page.body).to match(
        /<select[^>]* id="field_test_nested_field_tests_attributes_new_nested_field_tests_another_field_test_id"[^>]*>/
      )
    end

    it "hides fields that are deeply nested with inverse_of", js: false do
      visit new_path(model_name: "field_test")
      expect(page.body).to_not include("field_test_nested_field_tests_attributes_new_nested_field_tests_deeply_nested_field_tests_attributes_new_deeply_nested_field_tests_nested_field_test_id_field")
      expect(page.body).to include("field_test_nested_field_tests_attributes_new_nested_field_tests_deeply_nested_field_tests_attributes_new_deeply_nested_field_tests_title")
    end
  end

  context "when XSS attack is attempted" do
    it "does not break on adding a new item" do
      allow(I18n).to receive(:t).and_call_original
      expect(I18n).to receive(:t).with("admin.form.new_model", name: "Nested field test").and_return('<script>throw "XSS";</script>')
      visit edit_path(model_name: "field_test", id: field_test.id)
      find("#field_test_nested_field_tests_attributes_field .add_nested_fields").click
    end

    it "does not break on editing an existing item" do
      NestedFieldTest.create! title: '<script>throw "XSS";</script>', field_test: field_test
      visit edit_path(model_name: "field_test", id: field_test.id)
    end
  end
end
