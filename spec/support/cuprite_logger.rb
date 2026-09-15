# frozen_string_literal: true

class ConsoleLogger
  # Lines Ferrum wraps around the console message itself, which examples never want
  # forwarded to #warn — doing so also trips a `receive(:warn).with(...)` stub, and
  # the resulting error is raised on Ferrum's subscriber thread, killing it. Its CDP
  # protocol frames start "    ◀" or "\n\n▶"; since ferrum 0.18 it also logs one
  # "    at fn (url:line:col)" line per stack frame of the call.
  NOISE = /\A(?:    (?:◀|at )|\n\n▶)/

  def self.puts(message)
    warn(message) unless message.to_s.match?(NOISE)
  end
end
