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

  # A refused delete is the other back_or_index caller: a destroy blocked by
  # dependent: :restrict_with_exception redirects (303) instead of rendering.
  context "when a delete is refused by a dependent restriction" do
    let!(:restricted_team) { FactoryBot.create(:player, team: FactoryBot.create(:exception_restricted_team)).team }

    hostile_return_tos.each do |hostile_url|
      it "falls back to the index page for a hostile return_to of #{hostile_url.inspect}" do
        delete delete_path(model_name: "exception_restricted_team", id: restricted_team.id, return_to: hostile_url)

        expect(response.response_code).to eq(303)
        expect(URI.parse(response.headers["Location"]).path).to eq(index_path(model_name: "exception_restricted_team"))
      end
    end
  end

  it "follows a legitimate same-host return_to" do
    put edit_path(model_name: "player", id: player.id),
      params: {player: {name: player.name, number: player.number}, return_to: "/admin/team"}

    expect(response.response_code).to eq(302)
    expect(URI.parse(response.headers["Location"]).path).to eq("/admin/team")
  end
end
