# frozen_string_literal: true

require "spec_helper"
require "rails/hyperdrive/bundler_artifact_discovery"

RSpec.describe "Rails Hyperdrive discovery of this gem" do
  # The Bundler path-source spec, not Gem::Specification.load: discovery resolves skill roots
  # against full_gem_path, which only the Bundler spec points at this checkout.
  let(:spec) { Bundler.load.specs.find { |s| s.name == "rails_admin_next" } }
  let(:report) { Rails::Hyperdrive::BundlerArtifactDiscovery::Report.new }
  let(:skills) { Rails::Hyperdrive::BundlerArtifactDiscovery.discover(specs: [spec], report: report).select(&:skill?) }

  it "finds exactly the rails-admin-next skill and installs it under .claude/skills", :aggregate_failures do
    expect(skills.map(&:name)).to eq(["rails-admin-next"])
    expect(Rails::Hyperdrive::InstallLayout.dest_for(:skill, skills.first.name)).to eq(".claude/skills/rails-admin-next/SKILL.md")
    expect(report.skips).to be_empty
  end
end
