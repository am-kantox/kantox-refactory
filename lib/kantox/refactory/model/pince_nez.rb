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

        # @param [String] model
        def initialize model
          m = model.is_a?(String) ? model.clever_constantize : model
          fail ArgumentError.new("#{self.class.name}#initialize expects a descendant of ActiveRecord::Base as an argument") unless m.ancestors.include?(ActiveRecord::Base)
          @model = m
        end

        # @return [TrueClass|FalseClass] true if a model has no children (no `:has_many` assoc,) false otherwise
        def leaf?
          reflections([:has_many, :has_and_belongs_to_many]).empty?
        end

        # Returns a hash, accumulating/grouping methods representing dates,
        #     string fields that might be grouped, data interpreted as series, keys and the rest.
        # @return [Hash] { date: [..], group: [..], series: [..], keys: [..], garbage: [..] }
        def columns eager_group = true
          unless @columns
            @columns = @model.columns.inject({ date: [], group: {}, series: [], keys: [], garbage: [], grouped: false }) do |memo, column|
              case column.type
                when :datetime then memo[:date]
                when :integer  then memo[column.name == 'id' || column.name[-3..-1] == '_id' ? :keys : :series]
                else                memo[:garbage]
              end << column
              memo
            end
          end
          group_columns if eager_group
        end

        # @return [String]
        def crawl
          return @children if @children

          @children = reflections [:has_one, :belongs_to]
        end

      private
        def reflections types, inverse = false # :nodoc:
          @model.reflections.select { |_, v| inverse ^ [*types].include?(v.macro) }
        end

        # Builds `group` columns
        # @return [Hash] @columns
        def group_columns
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
