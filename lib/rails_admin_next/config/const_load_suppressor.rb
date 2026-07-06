# frozen_string_literal: true

module RailsAdminNext
  module Config
    module ConstLoadSuppressor
      class << self
        @original_const_missing = nil

        def suppressing
          raise "Constant Loading is already suppressed" if @original_const_missing

          begin
            @original_const_missing = Object.method(:const_missing)
            intercept_const_missing
            yield
          ensure
            Object.define_singleton_method(:const_missing, @original_const_missing)
            @original_const_missing = nil
          end
        end

        def allowing
          if @original_const_missing
            begin
              Object.define_singleton_method(:const_missing, @original_const_missing)
              yield
            ensure
              intercept_const_missing
            end
          else
            yield
          end
        end

        private

        def intercept_const_missing
          Object.define_singleton_method(:const_missing) do |name|
            ConstProxy.new(name.to_s)
          end
        end
      end

      class ConstProxy < BasicObject
        attr_reader :name

        def initialize(name)
          @name = name
        end

        def klass
          @klass ||=
            begin
              unless ::Object.const_defined?(name)
                ::Kernel.raise <<~MESSAGE
                  The constant #{name} is not loaded yet upon the execution of the RailsAdminNext initializer.
                  We don't recommend to do this and may lead to issues, but if you really have to do so you can explicitly require it by adding:

                    require '#{name.underscore}'

                  on top of config/initializers/rails_admin_next.rb.
                MESSAGE
              end
              name.constantize
            end
        end

        def method_missing(method_name, *, &)
          klass.send(method_name, *, &)
        end

        def respond_to_missing?(method_name, include_private = false)
          super || klass.respond_to?(method_name, include_private)
        end
      end
    end
  end
end
