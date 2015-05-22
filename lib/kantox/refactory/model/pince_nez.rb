require 'active_record/base'

module Kantox
  module Refactory
    module Model
      class PinceNez
        attr_reader :model

        # Defines unique records percent to decide whether grouping might be interesting on that column
        # @default 10 whether total amount of records divided by unique records number is less or equal to ten,
        #     the column will be considered interesting for grouping by
        GROUP_FACTOR = 10

        # @param [String|Symbol|::ActiveRecord::Reflection] model
        def initialize model
          m = case model
              when ::String, ::Symbol then model.clever_constantize
              when ::ActiveRecord::Reflection::ThroughReflection,
                   ::ActiveRecord::Reflection::MacroReflection
                model.model_class
              else model.respond_to?(:ancestors) ? model : model.class # FIXME better way to understand if we got an instance???
              end
          unless m && m < ::ActiveRecord::Base
            binding.pry
            fail ArgumentError.new("#{self.class.name}#initialize expects a descendant of ActiveRecord::Base as an argument. Got: #{model}")
          end

          @model = m
        end

        def name
          @model.name
        end

        # @return [TrueClass|FalseClass] true if a model has no children (no `:has_many` assoc,) false otherwise
        def leaf?
          reflections([:has_many, :has_and_belongs_to_many]).empty?
        end

        # Returns a hash, accumulating/grouping methods representing dates,
        #     string fields that might be grouped, data interpreted as series, keys and the rest.
        # @return [Hash] { date: [..], group: [..], series: [..], keys: [..], garbage: [..] }
        def columns eager_group = true
          @columns = sort_columns(@model.columns) unless @columns
          group_columns! if eager_group
        end

        # @return [String]
        def crawl
          @children ||= reflections([:has_one, :belongs_to]).inject({}) do |memo, (name, r)|
            memo[name] = { reflection: r, pince_nez: PinceNez.new(r) }
            memo
          end
        end

        def to_s
          "#<#{self.class}:#{'0x%016x' % (self.__id__ << 1)} #{exposed_to_s}>"
        end

        def inspect
          # "#<#{self.class}:#{'0x%016x' % (self.__id__ << 1)} #{exposed_inspect}>"
          "#<★PinceNez #{@model.name}>"
        end

      protected

        def exposed_to_s
          crawl.map do |name, rinfo|
            [name, rinfo[:pince_nez].model.name ]
          end.to_h
        end

        def exposed_inspect_full
          {
              properties: exposed_inspect,
              reflections: @model.reflections.map do |name, r|
                [name, { name: r.name, macro: r.macro, options: r.options, ar: r.active_record.name }]
              end.to_h,
              columns: @columns
          }
        end

      private

        def reflections types, inverse = false # :nodoc:
          @model.reflections.select { |_, v| inverse ^ [*types].include?(v.macro) }
        end

        def sort_columns columns
          columns.inject({ date: [], group: {}, series: [], keys: [], garbage: [], grouped: false }) do |memo, column|
            case column.type
              when :datetime then memo[:date]
              when :integer  then memo[column.name == 'id' || column.name[-3..-1] == '_id' ? :keys : :series]
              else                memo[:garbage]
            end << column
            memo
          end
        end

        # Builds `group` columns
        # @return [Hash] @columns
        def group_columns!
          fail 'Lame programmer error' unless @columns.is_a? Hash
          unless @columns[:grouped]
            total = @model.count
            %i(keys garbage).each do |k|
              @columns[:group][k] = @columns[k].select do |col|
                                      @model.group(col.name.to_sym).count.count * 100 / GROUP_FACTOR < total
                                    end
            end
            @columns[:grouped] = true
          end
          @columns
        end
      end
    end
  end
end
