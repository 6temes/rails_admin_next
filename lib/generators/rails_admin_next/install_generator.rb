# frozen_string_literal: true

require "rails/generators"
require "rails_admin_next/version"
require File.expand_path("utils", __dir__)

module RailsAdminNext
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)
    include Generators::Utils::InstanceMethods

    argument :_namespace, type: :string, required: false, desc: "RailsAdminNext url namespace"
    desc "RailsAdminNext installation generator"

    # RailsAdminNext ships a single zero-build asset path: browser-native ESM + CSS served by Propshaft and
    # pinned with an engine-owned importmap. The engine is self-contained, so installation is just the
    # mount point and an initializer — no bundler detection, yarn add, CSS build, or generated pins.
    def install
      if File.read(File.join(destination_root, "config/routes.rb")).include?("mount RailsAdminNext::Engine")
        display "Skipped route addition, since it's already there"
      else
        namespace = ask_for("Where do you want to mount RailsAdminNext?", "admin", _namespace)
        route("mount RailsAdminNext::Engine => '/#{namespace}', as: 'rails_admin_next'")
      end

      if File.exist? File.join(destination_root, "config/initializers/rails_admin_next.rb")
        display "Skipped initializer creation, since config/initializers/rails_admin_next.rb already exists"
      else
        template "initializer.erb", "config/initializers/rails_admin_next.rb"
      end

      display <<~MSG
        RailsAdminNext uses a zero-build asset pipeline: browser-native ESM and CSS served by Propshaft and
        pinned through an engine-owned importmap. There is no yarn/build step. Make sure your app uses
        Propshaft and importmap-rails (both are bundled automatically as RailsAdminNext dependencies).
      MSG
    end
  end
end
