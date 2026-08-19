# frozen_string_literal: true

require "spec_helper"

class ConfigurableTest
  include RailsAdminNext::Config::Configurable

  register_instance_option :foo do
    "default"
  end

  register_instance_option :bar? do
    true
  end
end

RSpec.describe RailsAdminNext::Config::Configurable do
  subject { ConfigurableTest.new }

  describe ".register_instance_option" do
    let(:configurable) { Class.new { include RailsAdminNext::Config::Configurable } }

    it "leaves the name it was given alone" do
      # The file is frozen_string_literal, so an unfrozen copy is what separates
      # "was the argument mutated" from "did a frozen argument raise".
      option_name = +"mutable?"
      configurable.register_instance_option(option_name) { true }

      expect(option_name).to eq "mutable?"
    end

    it "accepts a frozen name" do
      expect { configurable.register_instance_option("frozen?") { true } }.not_to raise_error
    end

    it "keeps the un-chopped name as the registry key" do
      configurable.register_instance_option(:keyed?) { true }

      expect(configurable.new).to have_option "keyed?"
    end

    it "answers a boolean option by either name", :aggregate_failures do
      expect(subject.bar).to be true
      expect(subject.bar?).to be true
    end

    it "reads the alias through the getter rather than duplicating its state" do
      subject.bar false

      expect(subject.bar?).to be false
    end
  end

  describe "recursion tracking" do
    it "works and use default value" do
      subject.instance_eval do
        foo { foo }
      end
      expect(subject.foo).to eq "default"
    end

    describe "with parallel execution" do
      before do
        subject.instance_eval do
          foo do
            sleep 0.15
            "value"
          end
        end
      end

      it "ensures thread-safety" do
        threads = Array.new(2) do |i|
          Thread.new do
            sleep i * 0.1
            expect(subject.foo).to eq "value"
          end
        end
        threads.each(&:join)
      end
    end
  end
end
