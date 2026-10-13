# frozen_string_literal: true

class AddReservedWordField < ActiveRecord::Migration[6.0]
  def change
    add_column :field_tests, :order, :integer
  end
end
