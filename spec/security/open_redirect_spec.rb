# frozen_string_literal: true

require "spec_helper"

# return_to must resolve to the same scheme+host+port as the current request (or be a
# genuinely relative single-slash path). Browsers normalize a leading backslash to '/', so
# '/\evil.com' becomes the protocol-relative '//evil.com' if accepted — an off-site redirect.
# A bare String#start_with?('/') check would also let 'http://<host>@evil.com' (userinfo) and
# 'http://<host>.evil.com' (no host boundary) slip through; this spec pins all three bypass
# classes closed.
RSpec.describe "return_to redirect is host-locked", type: :request do
  let!(:player) { FactoryBot.create(:player, team: FactoryBot.create(:team)) }

  hostile_return_tos = [
    "//evil.com",
    '/\evil.com',
    "https://evil.com",
    "http://evil.com@ok",
    "http://www.example.com.evil.com"
  ]

  hostile_return_tos.each do |hostile_url|
    it "falls back to the index page for a hostile return_to of #{hostile_url.inspect}" do
      put edit_path(model_name: "player", id: player.id),
        params: {player: {name: player.name, number: player.number}, return_to: hostile_url}

      expect(response.response_code).to eq(302)
      expect(URI.parse(response.headers["Location"]).path).to eq(index_path(model_name: "player"))
    end
  end

  it "follows a legitimate same-host return_to" do
    put edit_path(model_name: "player", id: player.id),
      params: {player: {name: player.name, number: player.number}, return_to: "/admin/team"}

    expect(response.response_code).to eq(302)
    expect(URI.parse(response.headers["Location"]).path).to eq("/admin/team")
  end
end
