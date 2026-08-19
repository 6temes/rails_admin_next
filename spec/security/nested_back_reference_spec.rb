# frozen_string_literal: true

require "spec_helper"

# A nested subform does not draw the child's link back to the record being edited, and the
# permitted parameters follow: `sanitize_params_for!` drops that key at nested depth. What makes
# it worth a security spec is the collection shape — `has_many :comments, as: :commentable` on
# NestedTeam. `assign_nested_attributes_for_collection_association` assigns straight onto an
# already-associated record, so before the allowlist change a crafted id moved the child onto
# another parent; the singular shape never did.
RSpec.describe "Nested back-reference", type: :request do
  let!(:other_team) { FactoryBot.create :team }
  let(:team) { NestedTeam.find(FactoryBot.create(:team).id) }

  it "attaches a nested comment to the record being edited, not to a crafted target" do
    put edit_path(model_name: "nested_team", id: team.id), params: {
      nested_team: {
        comments_attributes: {
          "new_1" => {
            content: "a comment",
            commentable_type: "Team",
            commentable_id: other_team.id.to_s
          }
        }
      }
    }

    expect(team.comments.reload.map(&:content)).to eq ["a comment"]
    expect(other_team.comments.reload).to be_empty
  end

  # The singular shape defends itself: saving the has_one re-applies the owner to the child, so
  # both halves of the polymorphic key come back whatever was submitted. This example passes with
  # or without the allowlist change — it is here to pin that, because the collection example
  # below is the contrast and the difference between them is easy to assume away.
  it "cannot retype an existing nested comment onto another model" do
    field_test = FactoryBot.create :field_test
    comment = field_test.create_comment! content: "a comment"

    put edit_path(model_name: "field_test", id: field_test.id), params: {
      field_test: {
        comment_attributes: {id: comment.id.to_s, content: "edited", commentable_type: "Team"}
      }
    }

    expect(comment.reload.content).to eq "edited"
    expect(comment.commentable_type).to eq "FieldTest"
  end

  it "cannot move an existing nested comment onto another record" do
    comment = team.comments.create! content: "a comment"

    put edit_path(model_name: "nested_team", id: team.id), params: {
      nested_team: {
        comments_attributes: {
          "0" => {
            id: comment.id.to_s,
            content: "edited",
            commentable_type: "Team",
            commentable_id: other_team.id.to_s
          }
        }
      }
    }

    expect(comment.reload.content).to eq "edited"
    # `as: :commentable` stores the base class, so compare the pair rather than the object.
    expect([comment.commentable_type, comment.commentable_id]).to eq ["Team", team.id]
    expect(other_team.comments.reload).to be_empty
  end
end
