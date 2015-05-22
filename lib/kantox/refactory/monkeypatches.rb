require 'active_support/inflector'

module Kantox
  module Refactory
    module MonkeyPatches
      class ::String
        # tries the following:
        #    self.constantize
        #    self.camelize.constantize
        #    self.singularize.constantize
        def clever_constantize
          self.safe_constantize || self.camelize.safe_constantize || self.singularize.camelize.safe_constantize
        end
      end

      class ::Symbol
        def clever_constantize
          self.to_s.clever_constantize
        end
      end

      class ::Object
        def exposed_to_s
          nil
        end

        alias_method :original_to_s, :to_s
        def to_s
          exposed_to_s ? "#<#{self.class}:#{'0x%16x' % (self.__id__ << 1)} #{exposed_to_s}>" : original_to_s
        end
      end

      class ::ActiveRecord::Reflection::ThroughReflection
        def model_class
          src = source_reflection || through_reflection
          while src.options[:through] do
            src = src.source_reflection || src.through_reflection
          end
          (src.options[:class_name] || src.name).clever_constantize || active_record
        end
      end

      class ::ActiveRecord::Reflection::MacroReflection
        def model_class
          (options[:class_name] || name).clever_constantize || active_record
        end
      end

    end
  end
end
