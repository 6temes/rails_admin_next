# frozen_string_literal: true

require "spec_helper"

# Destructive confirmation must not rely on `@rails/ujs`'s `data-confirm`, which requires the
# UJS runtime to intercept clicks and silently no-ops without it. Turbo reads
# `data-turbo-confirm` instead. This gate fails the suite if any UJS `data-confirm` /
# `data: { confirm: }` reappears under the engine, and locks the Turbo confirm onto the
# destructive submits.
RSpec.describe "Destructive-action confirmation", type: :request do
  subject { page }

  describe "grep gate" do
    it "has no @rails/ujs data-confirm anywhere under app/ or lib/" do
      ujs_confirm_attr = /data-confirm/
      ujs_confirm_hash = /data:\s*\{[^}]*['"]?confirm['"]?\s*(=>|:)/m
      root = RailsAdminNext::Engine.root
      files = %w[app lib].flat_map { |dir| Dir.glob(root.join(dir, "**", "*.{rb,erb}")) }
      offenders = files.select do |file|
        contents = File.read(file)
        contents.match?(ujs_confirm_attr) || contents.match?(ujs_confirm_hash)
      end
      expect(offenders).to be_empty,
        "Use data-turbo-confirm, not @rails/ujs data-confirm, in: #{offenders.map { |f| f.sub(root.to_s, "") }.join(", ")}"
    end
  end

  describe "data-turbo-confirm on destructive submits" do
    let!(:player) { FactoryBot.create(:player, team: FactoryBot.create(:team)) }

    it "guards the delete confirmation submit" do
      visit delete_path(model_name: "player", id: player.id)
      is_expected.to have_css("button[data-turbo-confirm], form[data-turbo-confirm]")
    end

    it "guards the bulk_delete confirmation submit" do
      players = FactoryBot.create_list(:player, 2)
      post bulk_action_path(bulk_action: "bulk_delete", model_name: "player", bulk_ids: players.collect(&:id))
      expect(response.body).to match(/data-turbo-confirm/)
    end
  end
end
