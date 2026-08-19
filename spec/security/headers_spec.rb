# frozen_string_literal: true

require "spec_helper"

# The privileged admin always advertises X-Frame-Options: SAMEORIGIN, and ships a
# Content Security Policy that is opt-in (the engine enforces no policy by default). When a host
# opts in, the engine threads a per-request nonce onto its inline tags so the policy can use
# `:self` + nonces without blocking the admin's own pinned modules.
RSpec.describe "Security headers", type: :request do
  # Every link tag the engine's head emits that the style-src directive governs: the stylesheets
  # themselves and the preloads of the sheets the entry stylesheet @imports.
  def style_tags
    page.body.scan(/<link\b[^>]*>/).grep(/rel="stylesheet"|as="style"/)
  end

  it "sets X-Frame-Options: SAMEORIGIN on admin responses" do
    visit dashboard_path
    expect(page.response_headers["X-Frame-Options"]).to eq("SAMEORIGIN")
  end

  describe "Content Security Policy" do
    it "enforces no policy by default (opt-in)" do
      visit dashboard_path
      expect(page.response_headers["Content-Security-Policy"]).to be_nil
      expect(page.response_headers["Content-Security-Policy-Report-Only"]).to be_nil
    end

    it "renders no nonce attribute on style tags when no policy is configured" do
      visit dashboard_path
      expect(style_tags).not_to be_empty
      expect(style_tags.join).not_to include("nonce")
    end

    context "when a host opts in" do
      before do
        RailsAdminNext.config do |config|
          config.content_security_policy do |policy|
            policy.default_src :self
            policy.script_src :self
          end
        end
      end

      it "enforces the policy and threads a nonce onto the inline importmap tag" do
        visit dashboard_path
        csp = page.response_headers["Content-Security-Policy"]
        expect(csp).to include("default-src 'self'")
        expect(csp).to match(/script-src 'self' 'nonce-[^']+'/)
        expect(page.body).to match(/<script type="importmap"[^>]*\bnonce="[^"]+"/)
      end

      # A nonce-based style-src blocks a preload as readily as a stylesheet, so both kinds of
      # link tag are asserted together, and against the same nonce the scripts were given.
      it "threads that same nonce onto every stylesheet and style-preload tag" do
        visit dashboard_path
        nonce = page.body[/<script type="importmap"[^>]*\bnonce="([^"]+)"/, 1]

        expect(style_tags).not_to be_empty
        expect(style_tags).to all(include(%(nonce="#{nonce}")))
      end
    end

    context "in report-only mode" do
      before do
        RailsAdminNext.config do |config|
          config.content_security_policy(report_only: true) do |policy|
            policy.default_src :self
          end
        end
      end

      it "sends the report-only header without enforcing" do
        visit dashboard_path
        expect(page.response_headers["Content-Security-Policy-Report-Only"]).to include("default-src 'self'")
        expect(page.response_headers["Content-Security-Policy"]).to be_nil
      end
    end
  end
end
