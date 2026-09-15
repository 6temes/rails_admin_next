# frozen_string_literal: true

require "spec_helper"

RSpec.describe ConsoleLogger do
  # The stack-frame lines arrive on Ferrum's own subscriber thread, so forwarding one
  # to a `receive(:warn).with(...)` stub kills that thread and fails every later
  # js example — which is why they are filtered rather than merely tolerated.
  it "forwards a console message" do
    expect(described_class).to receive(:warn).with("ActionText assets should be loaded statically")

    described_class.puts("ActionText assets should be loaded statically")
  end

  it "skips Ferrum's CDP protocol frames" do
    expect(described_class).not_to receive(:warn)

    described_class.puts("    ◀ {\"method\":\"Runtime.consoleAPICalled\"}")
    described_class.puts("\n\n▶ {\"id\":42}")
  end

  it "skips ferrum 0.18's stack-frame lines" do
    expect(described_class).not_to receive(:warn)

    described_class.puts("    at handleClick (http://127.0.0.1:3000/assets/rails_admin.js:12:7)")
  end

  it "forwards a message that merely mentions a stack frame" do
    expect(described_class).to receive(:warn).with("Error at handleClick (app.js:1:1)")

    described_class.puts("Error at handleClick (app.js:1:1)")
  end
end
