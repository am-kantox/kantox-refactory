require 'graphviz'
require 'bloomit'

module Kantox
  module Refactory
    module Model
      class Telescope
        COLORS = [0xFF, 0xCC, 0x88, 0x44, 0].repeated_permutation(3).to_a.shuffle

        attr_reader :tree, :yielded
        # @param [String|Symbol|::ActiveRecord::Reflection] model
        def initialize model, levels = 20, count_through = true
          @model = model
          @count_through = count_through
          @levels = levels
          @yielded = [PinceNez.new(model)]
          (@tree = {})[@yielded.first] = crawl_level @yielded.first, @levels
        end

        def to_graph reuse_nodes = true, filename = nil
          g = GraphViz.new(:G, :type => :digraph)
          @tree.each do |_, v|
            root = g.add_nodes v[:model].name, { shape: :box, style: :filled, color: yield_color(v[:model].name) }
            level_to_graph g, root, v[:children], { v[:model].name => root }, [], @levels, reuse_nodes
          end
          puts "Will write doc/#{@tree.keys.map(&:name).join('+')}_#{@count_through ? 'thru' : 'direct'}_#{reuse_nodes ? 'uniq' : 'all'}_#{@levels}.png"
          g.output(png: filename || "doc/#{@tree.keys.map(&:name).join('+')}_#{@count_through ? 'thru' : 'direct'}_#{reuse_nodes ? 'uniq' : 'all'}_#{@levels}.png")
        end

        def to_plant_uml filename = nil
          plantuml = "@startuml\n" # scale 8000 width\n"
          @tree.each do |_, v|
            plantuml << level_to_plant_uml(v)
          end
          plantuml << "\n@enduml"

          filename ||= "doc/#{@tree.keys.map(&:name).join('+')}.plantuml"
          File.open(filename, 'w') do |f|
            f.puts plantuml
          end
        end

      private
        def yielded tree = @tree
          tree.keys | tree.values.inject([]) do |memo, v|
                        memo << yielded(v) if v.is_a?(Hash)
                        memo
                      end
        end

        def crawl_level model, levels
            {
              model: model,
              children: levels <= 0 ? {} : model.crawl(@count_through).map do |name, r|
                          ar = r[:reflection].model_class
                          [
                              name,
                              @yielded.include?(ar) ? { model: r[:pince_nez], type: r[:reflection].macro, children: {} } :
                                  begin
                                    @yielded << ar
                                    crawl_level r[:pince_nez], levels - 1
                                  end
                          ]
                        end.to_h
            }
        end

        def yield_color model_name
          @colors ||= {}
          @colors[model_name] ||= model_name.to_color # COLORS[@colors.size % COLORS.size]
          # "##{@colors[model_name].map { |c| "%02x" % c }.join}"
        end

        def graph_node_params model, reuse_nodes, levels
          # reuse_nodes ?
          #    [model.name, "grey#{30 + (@levels - levels) * 70 / @levels}"] :
          #    ["#{model.name}:#{model.__id__}", yield_color(model.name)]
          [reuse_nodes ? model.name : "#{model.name}:#{model.__id__}", yield_color(model.name)]
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

        def level_to_plant_uml model
          model[:children].inject([]) do |memo, (k, v)|
            # FIXME different types of connectors
            memo << "#{model[:model].name} #{'o' if v[:type] == :belongs_to}-- #{v[:model].name} : #{k} >" \
                 << level_to_plant_uml(v)
          end.join("\n")
        end
      end
    end
  end
end
