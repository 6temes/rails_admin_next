# frozen_string_literal: true

require "spec_helper"

# Server-rendered strings that can carry user/host content must render inert. Stimulus
# controllers build DOM with textContent/template-cloning rather than innerHTML, so this locks
# down the server side instead — flash validation messages and configured labels.
RSpec.describe "XSS in admin output", type: :request do
  let(:script) { "<script>alert(document.cookie)</script>" }
  let(:escaped) { "&lt;script&gt;alert(document.cookie)&lt;/script&gt;" }

  it "renders a validation message containing markup inert in the flash" do
    team = FactoryBot.create(:team)
    allow_any_instance_of(Player).to receive(:save).and_return(false)
    errors = ActiveModel::Errors.new(Player.new)
    errors.add(:base, script)
    allow_any_instance_of(Player).to receive(:errors).and_return(errors)

    page.driver.post(new_path(model_name: "player"), player: {name: "x", team_id: team.id})

    expect(page.driver.response.body).to include(escaped)
    expect(page.driver.response.body).not_to include(script)
  end

  it "renders a configured field label containing markup inert" do
    player = FactoryBot.create(:player, team: FactoryBot.create(:team))
    RailsAdminNext.config Player do
      edit do
        field :name do
          label "<script>alert(1)</script>"
        end
      end
    end

    visit edit_path(model_name: "player", id: player.id)

    expect(page.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    expect(page.body).not_to include("<script>alert(1)</script>")
  end
end
