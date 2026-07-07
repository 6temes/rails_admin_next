# frozen_string_literal: true

module RailsAdminNext
  module Config
    module Proxyable
      class Proxy < BasicObject
        def initialize(object, bindings = {})
          @object = object
          @bindings = bindings
        end

        # Bind variables to be used by the configuration options
        def bind(key, value = nil)
          if key.is_a?(::Hash)
            @bindings = key
          else
            @bindings[key] = value
          end
          self
        end

        # Transparent proxy: `Proxy < BasicObject` has no `respond_to?`, so
        # `respond_to_missing?` would be dead code (nothing ever calls it) — a
        # bare `proxy.respond_to?(:x)` is itself delegated through method_missing.
        def method_missing(method_name, *, &) # standard:disable Style/MissingRespondToMissing
          if @object.respond_to?(method_name)
            reset = @object.bindings
            begin
              @object.bindings = @bindings
              response = @object.__send__(method_name, *, &)
            ensure
              @object.bindings = reset
            end
            response
          else
            super
          end
        end
      end
    end
  end
end
