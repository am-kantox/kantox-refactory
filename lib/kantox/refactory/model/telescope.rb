require 'graphviz'

module Kantox
  module Refactory
    module Model
      class Telescope
        COLORS = [0xFF, 0xCC, 0x88, 0x44, 0].repeated_permutation(3).to_a.shuffle

        attr_reader :tree, :yielded
        # @param [String|Symbol|::ActiveRecord::Reflection] model
        def initialize model
          @model = model
          @max_levels = 20
          @yielded = [PinceNez.new(model)]
          (@tree = {})[@yielded.first] = crawl_level @yielded.first
        end

        def to_graph reuse_nodes = true, levels = -1, filename = nil
          g = GraphViz.new(:G, :type => :digraph)
          @max_levels = levels if levels > 0
          @tree.each do |_, v|
            root = g.add_nodes v[:model].name, { shape: :box, style: :filled, color: yield_color(v[:model].name) }
            level_to_graph g, root, v[:children], { v[:model].name => root }, [], levels, reuse_nodes
          end
          g.output(png: filename || "doc/#{@tree.keys.map(&:name).join('+')}_#{reuse_nodes ? 'uniq' : 'all'}_#{levels > 0 ? levels : 'all'}.png")
        end

      private
        def yielded tree = @tree
          tree.keys | tree.values.inject([]) do |memo, v|
                        memo << yielded(v) if v.is_a?(Hash)
                        memo
                      end
        end

        def crawl_level model
            {
              model: model,
              children: model.crawl.map do |name, r|
                          ar = r[:reflection].model_class
                          [
                              name,
                              @yielded.include?(ar) ? { model: r[:pince_nez], children: {} } :
                                  begin
                                    @yielded << ar
                                    crawl_level(r[:pince_nez])
                                  end
                          ]
                        end.to_h
            }
        end

        def yield_color model_name
          @colors ||= {}
          @colors[model_name] ||= COLORS[@colors.size % COLORS.size]
          "##{@colors[model_name].map { |c| "%02x" % c }.join}"
        end

        def graph_node_params model, reuse_nodes, levels
          reuse_nodes ?
            [model.name, "grey#{30 + (@max_levels - levels) * 70 / @max_levels}"] :
            ["#{model.name}:#{model.__id__}", yield_color(model.name)]
        end

        def level_to_graph g, root, children, nodes, edges, levels, reuse_nodes
          return if levels.zero?
          children.each do |k, v|
            node_name, node_color = graph_node_params(v[:model], reuse_nodes, levels)
            opts = { style: :filled, color: node_color }
            subroot = nodes[node_name] || g.add_nodes(node_name, opts).tap { |n| nodes[node_name] = n }
            next if edges.include? [root, subroot, k]
            g.add_edges(root, subroot, { label: k })
            edges << [root, subroot, k]
            level_to_graph g, subroot, v[:children], nodes, edges, levels - 1, reuse_nodes
          end
        end
      end
    end
  end
end
