# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext::Icons do
  describe ".svg" do
    it "renders an inline SVG for a logical name", :aggregate_failures do
      svg = described_class.svg(:edit)

      expect(svg).to start_with("<svg ")
      expect(svg).to include('viewBox="0 0 512 512"')
      expect(svg).to include('data-icon="edit"')
      expect(svg).to include('aria-hidden="true"')
      expect(svg).to include('class="rails-admin-icon"')
      expect(svg).to include('<path d="M421.7')
    end

    it "resolves an alias to its canonical glyph" do
      expect(described_class.svg(:pencil)).to eq(described_class.svg(:edit))
      expect(described_class.svg(:pencil)).to include('data-icon="edit"')
    end

    it "merges a caller-supplied class with the default" do
      expect(described_class.svg(:collapse, class: "collapsed"))
        .to include('class="rails-admin-icon collapsed"')
    end

    it "HTML-escapes a hostile attribute value", :aggregate_failures do
      svg = described_class.svg(:edit, class: %("><script>alert(1)</script>))

      expect(svg).to include('class="rails-admin-icon &quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;"')
      expect(svg).not_to include("<script>")
    end

    it "HTML-escapes a hostile attribute key", :aggregate_failures do
      hostile_key = :'evil"><script>alert(1)</script>'
      svg = described_class.svg(:edit, **{hostile_key => "y"})

      expect(svg).to include('evil&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;="y"')
      expect(svg).not_to include("<script>")
    end

    it "returns nil for nil" do
      expect(described_class.svg(nil)).to be_nil
    end

    it "returns nil for an unknown logical name" do
      expect(described_class.svg(:totally_unknown)).to be_nil
    end

    context "with a legacy Font Awesome class string" do
      it "resolves it best-effort and warns via the deprecator", :aggregate_failures do
        expect(RailsAdminNext.deprecator).to receive(:warn).with(/Font Awesome/)

        expect(described_class.svg("fas fa-home")).to include('data-icon="dashboard"')
      end

      it "renders nothing for an unmappable Font Awesome glyph" do
        allow(RailsAdminNext.deprecator).to receive(:warn)

        expect(described_class.svg("fas fa-rocket")).to be_nil
      end
    end
  end

  describe ".canonical" do
    it "returns the key itself for a canonical glyph" do
      expect(described_class.canonical(:delete)).to eq(:delete)
    end

    it "resolves an alias to its canonical glyph" do
      expect(described_class.canonical(:cancel)).to eq(:delete)
    end

    it "returns nil for an unknown name" do
      expect(described_class.canonical(:nope)).to be_nil
    end
  end

  describe ".fa_class?" do
    it "detects Font Awesome class strings", :aggregate_failures do
      expect(described_class.fa_class?("fas fa-home")).to be(true)
      expect(described_class.fa_class?("fa fa-fw fa-calendar")).to be(true)
    end

    it "does not flag a logical name", :aggregate_failures do
      expect(described_class.fa_class?("edit")).to be(false)
      expect(described_class.fa_class?(:edit)).to be(false)
    end
  end

  describe ".from_fa_class" do
    it "maps a Font Awesome glyph token to a logical name" do
      expect(described_class.from_fa_class("fas fa-pencil-alt")).to eq(:edit)
    end

    it "skips sizing modifiers to find the glyph token" do
      expect(described_class.from_fa_class("fa fa-fw fa-calendar")).to eq(:calendar)
    end

    it "returns nil for an unmappable token" do
      expect(described_class.from_fa_class("fas fa-rocket")).to be_nil
    end
  end
end
