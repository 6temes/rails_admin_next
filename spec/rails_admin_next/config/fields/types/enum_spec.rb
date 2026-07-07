# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Config::Fields::Types::Enum do
  it_behaves_like "a generic field type", :string_field, :enum

  subject { RailsAdminNext.config(Team).field(:color) }

  describe "when object responds to '\#{method}_enum'" do
    before do
      allow_any_instance_of(Team).to receive(:color_enum).and_return(%w[blue green red])
      RailsAdminNext.config Team do
        edit do
          field :color
        end
      end
    end

    it "auto-detects enumeration" do
      is_expected.to be_a(RailsAdminNext::Config::Fields::Types::Enum)
      is_expected.not_to be_multiple
      expect(subject.with(object: Team.new).enum).to eq %w[blue green red]
    end
  end

  describe "when class responds to '\#{method}_enum'" do
    before do
      allow(Team).to receive(:color_enum).and_return(%w[blue green red])
      Team.instance_eval do
        def color_enum
          %w[blue green red]
        end
      end
      RailsAdminNext.config Team do
        edit do
          field :color
        end
      end
    end

    it "auto-detects enumeration" do
      is_expected.to be_a(RailsAdminNext::Config::Fields::Types::Enum)
      expect(subject.with(object: Team.new).enum).to eq %w[blue green red]
    end
  end

  describe "the enum instance method" do
    before do
      Team.class_eval do
        def color_list
          %w[blue green red]
        end
      end
      RailsAdminNext.config Team do
        field :color, :enum do
          enum_method :color_list
        end
      end
    end

    after do
      Team.send(:remove_method, :color_list)
    end

    it "allows configuration" do
      is_expected.to be_a(RailsAdminNext::Config::Fields::Types::Enum)
      expect(subject.with(object: Team.new).enum).to eq %w[blue green red]
    end
  end

  describe "the enum class method" do
    before do
      Team.instance_eval do
        def color_list
          %w[blue green red]
        end
      end
      RailsAdminNext.config Team do
        field :color, :enum do
          enum_method :color_list
        end
      end
    end

    after do
      Team.instance_eval { undef :color_list }
    end

    it "allows configuration" do
      is_expected.to be_a(RailsAdminNext::Config::Fields::Types::Enum)
      expect(subject.with(object: Team.new).enum).to eq %w[blue green red]
    end
  end

  describe "when overriding enum configuration" do
    before do
      Team.class_eval do
        def color_list
          %w[blue green red]
        end
      end
      RailsAdminNext.config Team do
        field :color, :enum do
          enum_method :color_list
          enum do
            %w[yellow black]
          end
        end
      end
    end

    after do
      Team.send(:remove_method, :color_list)
    end

    it "allows direct listing of enumeration options and override enum method" do
      is_expected.to be_a(RailsAdminNext::Config::Fields::Types::Enum)
      expect(subject.with(object: Team.new).enum).to eq %w[yellow black]
    end
  end

  describe "when serialize is enabled in ActiveRecord model", active_record: true do
    subject { RailsAdminNext.config(TeamWithSerializedEnum).field(:color) }

    before do
      stub_const("TeamWithSerializedEnum", Class.new(Team) do
        self.table_name = "teams"
        serialize :color, coder: JSON
        def color_enum
          %w[blue green red]
        end
      end)
      RailsAdminNext.config do |c|
        c.included_models = [TeamWithSerializedEnum]
      end
    end

    it "makes enumeration multi-selectable" do
      is_expected.to be_multiple
    end
  end
end
