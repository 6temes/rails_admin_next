# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Extensions::ModelLineage do
  it "lists a record's superclasses nearest first" do
    stub_const("Softball", Class.new(Hardball))
    expect(described_class.superclasses(Softball.new)).to eq [Hardball, Ball]
  end

  it "stops before an abstract class" do
    stub_const("ConcreteModel", Class.new(Abstract))
    stub_const("ConcreteSubmodel", Class.new(ConcreteModel))
    expect(described_class.superclasses(ConcreteSubmodel)).to eq [ConcreteModel]
  end

  it "is empty for the dashboard's nil record" do
    expect(described_class.superclasses(nil)).to eq []
  end
end
