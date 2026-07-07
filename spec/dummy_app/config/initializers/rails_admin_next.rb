# frozen_string_literal: true

RailsAdminNext.config do |c|
  c.model Team do
    include_all_fields
    field :color, :hidden
  end

  if Rails.env.production?
    # Live demo configuration
    c.included_models = %w[Comment Division Draft Fan FieldTest League NestedFieldTest Player Team User]
    c.model "League" do
      configure :players do
        visible false
      end
    end
  end
end
