# frozen_string_literal: true

class AddStoreField < ActiveRecord::Migration[6.0]
  def change
    add_column :field_tests, :store_field, :text
  end
end
