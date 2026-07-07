# frozen_string_literal: true

require "spec_helper"
require "generators/rails_admin_next/install_generator"

RSpec.describe RailsAdminNext::InstallGenerator, type: :generator do
  destination File.expand_path("../dummy_app/tmp/generator", __dir__)
  arguments ["admin", "--force"]

  before do
    prepare_destination
    FileUtils.touch File.join(destination_root, "Gemfile")
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    File.write(File.join(destination_root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        # empty
      end
    RUBY
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  it "mounts RailsAdminNext as an Engine and generates the initializer (importmap + Propshaft, zero-build)" do
    Dir.chdir(destination_root) do
      run_generator
    end
    expect(destination_root).to(
      have_structure do
        directory "config" do
          directory "initializers" do
            file "rails_admin_next.rb" do
              contains "RailsAdminNext.config"
            end
          end
          file "routes.rb" do
            contains "mount RailsAdminNext::Engine => '/admin', as: 'rails_admin_next'"
          end
        end
      end
    )
    # The asset pipeline is fixed (importmap + Propshaft); no asset_source option is written.
    initializer = File.read(File.join(destination_root, "config/initializers/rails_admin_next.rb"))
    expect(initializer).not_to include "asset_source"
  end

  it "leaves an existing RailsAdminNext initializer untouched" do
    File.write(File.join(destination_root, "config/initializers/rails_admin_next.rb"), <<~RUBY)
      RailsAdminNext.config do |config|
        # pre-existing
      end
    RUBY
    Dir.chdir(destination_root) do
      run_generator
    end
    expect(File.read(File.join(destination_root, "config/initializers/rails_admin_next.rb"))).to include "# pre-existing"
  end
end
