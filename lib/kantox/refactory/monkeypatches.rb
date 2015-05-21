require 'active_support/inflector'

class String
  # tries the following:
  #    self.constantize
  #    self.camelize.constantize
  #    self.singularize.constantize
  def clever_constantize
    self.safe_constantize || self.camelize.safe_contantize || self.singularize.safe_constantize
  end
end