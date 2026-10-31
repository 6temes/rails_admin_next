# frozen_string_literal: true

# A nested form that can reach itself: every child category's form carries another
# child-categories form, so the nested form has to stop somewhere.
class NestedCategory < Category
  has_many :child_categories, class_name: "NestedCategory", foreign_key: :parent_category_id, inverse_of: :parent_category
  belongs_to :parent_category, class_name: "NestedCategory", optional: true, inverse_of: :child_categories
  accepts_nested_attributes_for :child_categories
end
