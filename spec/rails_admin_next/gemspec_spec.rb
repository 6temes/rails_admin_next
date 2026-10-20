# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rails_admin_next.gemspec" do
  let(:spec) { Gem::Specification.load(File.expand_path("../../rails_admin_next.gemspec", __dir__)) }

  it "ships the agent skill and the top-level docs it points at" do
    expect(spec.files).to include(
      "skills/rails-admin-next/SKILL.md",
      "docs/UPGRADING.md",
      "docs/security.md",
      "docs/upstream-parity.md"
    )
  end

  # docs/ subdirectories hold git-excluded local plans and notes, and `gem build` globs the working tree.
  it "ships nothing from docs/ subdirectories or spec/" do
    expect(spec.files).not_to include(a_string_matching(%r{\Adocs/[^/]+/|\Aspec/}))
  end

  it "opts in to Rails Hyperdrive as its own companion" do
    expect(spec.metadata["hyperdrive_targets"]).to eq("rails_admin_next")
  end
end
