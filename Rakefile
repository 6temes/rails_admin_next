# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

Dir["lib/tasks/*.rake"].each { |rake| load rake }

require "bundler"
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task test: :spec

begin
  require "standard/rake"
rescue LoadError
  desc "Run Standard"
  task :standard do
    warn "Standard is disabled"
  end
end

task default: %i[spec standard]
