module Kantox
  module Refactory
    module Model
      class Telescope
        attr_reader :tree, :yielded
        # @param [String|Symbol|::ActiveRecord::Reflection] model
        def initialize model
          @model = model
          @yielded = [PinceNez.new(model)]
          (@tree = {})[@yielded.first] = crawl_level @yielded.first
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
      end
    end
  end
end
