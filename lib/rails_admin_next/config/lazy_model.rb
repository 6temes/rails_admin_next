# frozen_string_literal: true

require "rails_admin_next/config/model"

module RailsAdminNext
  module Config
    class LazyModel < BasicObject
      def initialize(entity, &block)
        @entity = entity
        @deferred_blocks = [*block]
        @initialized = false
      end

      def add_deferred_block(&block)
        if @initialized
          @model.instance_eval(&block)
        else
          @deferred_blocks << block
        end
      end

      def target
        @model ||= ::RailsAdminNext::Config::Model.new(@entity)
        # When evaluating multiple configuration blocks, the order of
        # execution is important. As one would expect (in my opinion),
        # options defined within a resource should take precedence over
        # more general options defined in an initializer. This way,
        # general settings for a number of resources could be specified
        # in the initializer, while models could override these settings
        # later, if required.
        #
        # CAVEAT: It cannot be guaranteed that blocks defined in an initializer
        # will be loaded (and adde to @deferred_blocks) first. For instance, if
        # the initializer references a model class before defining
        # a RailsAdminNext configuration block, the configuration from the
        # resource will get added to @deferred_blocks first:
        #
        #     # app/models/some_model.rb
        #     class SomeModel
        #       rails_admin_next do
        #         :
        #       end
        #     end
        #
        #     # config/initializers/rails_admin_next.rb
        #     model = 'SomeModel'.constantize # blocks from SomeModel get loaded
        #     model.config model do           # blocks from initializer gets loaded
        #       :
        #     end
        #
        # Thus, sort all blocks to execute for a resource by Proc.source_path,
        # to guarantee that blocks from 'config/initializers' evaluate before
        # blocks defined within a model class.
        unless @deferred_blocks.empty?
          @deferred_blocks
            .partition { |block| block.source_location.first =~ %r{config/initializers} }
            .flatten
            .each { |block| @model.instance_eval(&block) }
          @deferred_blocks = []
        end
        @initialized = true
        @model
      end

      def method_missing(method_name, *, &)
        target.send(method_name, *, &)
      end

      def respond_to_missing?(method_name, include_private = false)
        super || target.respond_to?(method_name, include_private)
      end
    end
  end
end
