# frozen_string_literal: true

# Team's comments are polymorphic (`has_many :comments, as: :commentable`), so this is the
# collection form of the nested back-reference: the child's link to its parent is a
# commentable_type/commentable_id pair that nothing on the Comment side names.
class NestedTeam < Team
  accepts_nested_attributes_for :comments, allow_destroy: true
end
