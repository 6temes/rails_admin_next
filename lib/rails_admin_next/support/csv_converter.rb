# frozen_string_literal: true

require "csv"

module RailsAdminNext
  class CSVConverter
    BATCH_SIZE = 1000

    def initialize(objects = [], schema = nil)
      @fields = []
      @associations = []
      schema ||= {}

      @objects = objects
      @model = objects.is_a?(ActiveRecord::Relation) ? objects.klass : objects.first&.class
      return unless @model

      @abstract_model = RailsAdminNext::AbstractModel.new(@model)
      @model_config = @abstract_model.config
      @methods = [(schema[:only] || []) + (schema[:methods] || [])].flatten.compact
      @fields = @methods.collect { |m| export_field_for(m) }.compact
      @empty = ::I18n.t("admin.export.empty_value_for_associated_objects")
      schema_include = schema.delete(:include) || {}

      @associations = schema_include.each_with_object({}) do |(key, values), hash|
        association = export_field_for(key)
        next unless association&.association?

        model_config = association.associated_model_config
        abstract_model = model_config.abstract_model
        methods = [(values[:only] || []) + (values[:methods] || [])].flatten.compact

        hash[key] = {
          association: association,
          model: abstract_model.model,
          abstract_model: abstract_model,
          model_config: model_config,
          fields: methods.collect { |m| export_field_for(m, model_config) }.compact
        }
        hash
      end
    end

    def to_csv(options = {})
      options = HashWithIndifferentAccess.new(options)
      encoding_to = Encoding.find(options[:encoding_to]) if options[:encoding_to].present?

      csv_string = generate_csv_string(options)
      csv_string = csv_string.encode(encoding_to, invalid: :replace, undef: :replace, replace: "?") if encoding_to

      # Add a BOM for utf8 encodings, helps with utf8 auto-detect for some versions of Excel.
      # Don't add if utf8 but user don't want to touch input encoding:
      # If user chooses utf8, they will open it in utf8 and BOM will disappear at reading.
      # But that way "English" users who don't bother and chooses to let utf8 by default won't get BOM added
      # and will not see it if Excel opens the file with a different encoding.
      csv_string = "\xEF\xBB\xBF#{csv_string}" if encoding_to == Encoding::UTF_8

      [!options[:skip_header], (encoding_to || csv_string.encoding).to_s, csv_string]
    end

    private

    def export_field_for(method, model_config = @model_config)
      model_config.export.fields.detect { |f| f.name == method }
    end

    def generate_csv_string(options)
      generator_options = (options[:generator] || {}).symbolize_keys.delete_if { |_, value| value.blank? }
      CSV.generate(**generator_options) do |csv|
        csv << generate_csv_header unless options[:skip_header]

        each_object do |object|
          csv << generate_csv_row(object)
        end
      end
    end

    def each_object(&)
      return @objects.each(&) unless @objects.is_a?(ActiveRecord::Relation)
      # Batching sets its own limit and offset, which would drop the relation's.
      return @objects.each(&) if @objects.limit_value || @objects.offset_value

      if (direction = primary_key_direction)
        @objects.unscope(:order).find_each(order: direction, batch_size: BATCH_SIZE, &)
      else
        each_in_offset_batches(&)
      end
    end

    # sort_scope writes the list sort as a single "<table>.<column> <direction>" string.
    def primary_key_direction
      primary_key = @model.primary_key
      return unless primary_key.is_a?(String)

      orders = @objects.order_values
      return :asc if orders.empty?
      return unless orders.one? && orders.first.is_a?(String)

      table = Regexp.escape(@model.table_name)
      column = Regexp.escape(primary_key)
      orders.first[/\A(?:\W?#{table}\W?\.)?\W?#{column}\W? (asc|desc)\z/i, 1]&.downcase&.to_sym
    end

    # The primary-key tie-break makes the order total, so rows that tie on the sort
    # column cannot shift between batches. A short batch is not the last one: sorting
    # on an eager-loaded has-many column returns fewer records than the limit.
    def each_in_offset_batches(&)
      ordered = @objects.order(Array(@model.primary_key).index_with(:asc))
      0.step(by: BATCH_SIZE) do |offset|
        batch = ordered.limit(BATCH_SIZE).offset(offset).to_a
        break if batch.empty?

        batch.each(&)
      end
    end

    def generate_csv_header
      @fields.collect do |field|
        ::I18n.t("admin.export.csv.header_for_root_methods", name: field.label, model: @abstract_model.pretty_name)
      end +
        @associations.flat_map do |_association_name, option_hash|
          option_hash[:fields].collect do |field|
            ::I18n.t("admin.export.csv.header_for_association_methods", name: field.label, association: option_hash[:association].label)
          end
        end
    end

    def generate_csv_row(object)
      @fields.collect do |field|
        field.with(object: object).export_value
      end +
        @associations.flat_map do |association_name, option_hash|
          associated_objects = [object.send(association_name)].flatten.compact
          option_hash[:fields].collect do |field|
            associated_objects.collect { |ao| field.with(object: ao).export_value.presence || @empty }.join(",")
          end
        end
    end
  end
end
