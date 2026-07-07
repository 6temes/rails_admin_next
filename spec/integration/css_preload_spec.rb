# frozen_string_literal: true

require "spec_helper"

# The rails_admin.css entry pulls tokens/framework/skin via @import, which the browser only
# discovers after fetching and parsing the entry file. The layout preloads the three targets so
# all four stylesheets fetch in parallel instead of as a serial waterfall.
RSpec.describe "CSS layer preloading", type: :request do
  it "preloads the three @import targets alongside the entry stylesheet" do
    get dashboard_path

    %w[tokens framework skin].each do |layer|
      expect(response.body).to match(
        %r{<link rel="preload" as="style" href="/assets/rails_admin/#{layer}-[0-9a-f]+\.css">}
      )
    end
  end
end
