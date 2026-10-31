# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Capybara driver restore" do
  # Not :js: the retry around hook and Capybara's :js driver switch would take the inner example over.
  it "restores the default driver after a dead browser aborts the session reset" do
    group = RSpec.describe "dead browser", type: :request do
      it "leaves the browser driver selected" do
        allow(Capybara).to receive(:reset_sessions!).and_raise(Ferrum::DeadBrowserError)
        Capybara.current_driver = :cuprite
      end
    end

    begin
      # The outer run's line or id filter would otherwise drop the inner example.
      RSpec.world.filtered_examples[group] = group.examples
      group.run(RSpec::Core::NullReporter)
      observed = Capybara.current_driver
      inner = group.examples.first.execution_result
    ensure
      RSpec.world.example_groups.delete(group)
      RSpec.world.filtered_examples.delete(group)
      Capybara.use_default_driver
    end

    # An inner example that never ran would leave the driver untouched and pass without proving anything.
    expect(inner.status).to eq(:failed)
    expect(inner.exception).to be_a(Ferrum::DeadBrowserError)
    expect(observed).to eq(Capybara.default_driver)
  end
end
