# frozen_string_literal: true

require "rails_admin_next/support/hash_helper"

module RailsAdminNext
  # The options handed to to_json/serializable_hash, limited to what a section
  # shows. Both serializers call every name under `methods` and `include` on each
  # record, and serialize every attribute when `only` is missing, so a requested
  # schema is only ever intersected with this, never passed through.
  class SerializationSchema
    def initialize(section, include_associations:)
      @section = section
      @include_associations = include_associations
    end

    # Attributes only: a virtual field need not be a method on the record, so
    # calling it unasked could raise where the plain serialization never did.
    def default
      {only: allowed[:only]}
    end

    def sanitize(requested)
      requested = HashHelper.symbolize(requested)
      schema = filter(requested, allowed)
      if @include_associations && requested[:include].is_a?(Hash)
        schema[:include] = requested[:include].each_with_object({}) do |(name, value), included|
          next unless value.is_a?(Hash) && allowed[:include].key?(name)

          included[name] = filter(value, allowed[:include][name])
        end
      end
      schema
    end

    private

    def allowed
      @allowed ||= begin
        fields = @section.visible_fields
        names = field_names(fields.select { |f| !f.association? || f.association.polymorphic? })
        if @include_associations
          names[:include] = fields.select { |f| f.association? && !f.association.polymorphic? }.to_h do |field|
            associated = field.associated_model_config.export.with(@section.bindings.merge(object: field.associated_model_config.abstract_model.model.new))
            [field.name, field_names(associated.visible_fields.reject(&:association?))]
          end
        else
          # The section already shows these associations, so their keys expose nothing more
          names[:only].concat(fields.select { |f| f.association? && f.association.type == :belongs_to && !f.association.polymorphic? }
            .flat_map { |f| Array(f.association.foreign_key).map(&:to_sym) })
        end
        names
      end
    end

    # Mirrors the names the export form offers (main/export.html.erb).
    def field_names(fields)
      fields.each_with_object({only: [], methods: []}) do |field, names|
        list = field.virtual? ? names[:methods] : names[:only]
        if field.association?
          list << field.method_name.to_sym << field.association.foreign_type.to_sym
        else
          list << field.name.to_sym
        end
      end
    end

    # An empty `only` serializes no attribute in ActiveRecord, which is the point.
    def filter(requested, permitted)
      schema = {only: Array(requested[:only]) & permitted[:only]}
      schema[:methods] = Array(requested[:methods]) & permitted[:methods] if requested.key?(:methods)
      schema
    end
  end
end
