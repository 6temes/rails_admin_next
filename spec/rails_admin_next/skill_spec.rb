# frozen_string_literal: true

require "spec_helper"

RSpec.describe "The rails-admin-next agent skill" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:text) { File.read(File.join(root, "skills/rails-admin-next/SKILL.md")) }
  let(:frontmatter) { YAML.safe_load(text[/\A---\n(.*?)\n---\n/m, 1]) }
  let(:shipped_files) { Gem::Specification.load(File.join(root, "rails_admin_next.gemspec")).files }

  it "carries the frontmatter Hyperdrive installs it by", :aggregate_failures do
    expect(frontmatter["name"]).to eq("rails-admin-next")
    expect(frontmatter["description"]).to include("rails_admin_next")
  end

  # `<gem>/` marks a path inside the installed gem; host-app paths are written without it.
  it "names only gem paths that ship in the gem" do
    gem_paths = text.scan(/`<gem>\/([^`]+)`/).flatten.uniq

    missing = gem_paths.reject { |path| shipped_files.any? { |file| file == path || file.start_with?(path) } }

    expect(missing).to be_empty
  end

  it "keeps :rails_admin as the authorization subject and only names :rails_admin_next to forbid it", :aggregate_failures do
    expect(text).to include("can :access, :rails_admin`")
    expect(text.lines.grep(/:rails_admin_next\b/)).to all(match(/\b(not|never|no longer)\b/i))
  end
end
