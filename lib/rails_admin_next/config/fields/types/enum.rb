# frozen_string_literal: true

require "rails_admin_next/config/fields/types/string"

module RailsAdminNext
  module Config
    module Fields
      module Types
        class Enum < RailsAdminNext::Config::Fields::Base
          RailsAdminNext::Config::Fields::Types.register(self)

          register_instance_option :filter_operators do
            %w[_discard] +
              enum.map do |label, value|
                {label: label, value: value || label}
              end + (required? ? [] : %w[_separator _present _blank])
          end

          register_instance_option :partial do
            :form_enumeration
          end

          register_instance_option :enum_method do
            @enum_method ||= begin
              method_name = "#{name}_enum"
              method_name if (bindings[:object]&.class || abstract_model.model).respond_to?(method_name) ||
                (bindings[:object] || abstract_model.model.new).respond_to?(method_name)
            end
          end

          register_instance_option :enum do
            if enum_method.nil?
              []
            elsif abstract_model.model.respond_to?(enum_method)
              abstract_model.model.send(enum_method)
            else
              (bindings[:object] || abstract_model.model.new).send(enum_method)
            end
          end

          register_instance_option :pretty_value do
            if enum.is_a?(::Hash)
              enum.select { |_k, v| v.to_s == value.to_s }.keys.first.to_s.presence || value.presence || " - "
            elsif enum.is_a?(::Array) && enum.first.is_a?(::Array)
              enum.detect { |e| e[1].to_s == value.to_s }.try(:first).to_s.presence || value.presence || " - "
            else
              value.presence || " - "
            end
          end

          register_instance_option :multiple? do
            properties && [:serialized].include?(properties.type)
          end
        end
      end
    end
  end
end
