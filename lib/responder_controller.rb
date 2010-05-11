require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'

module ResponderController

  def self.included(mod)
    mod.extend ClassMethods
    mod.send :include, InstanceMethods
  end

  module ClassMethods

    def model_class_name
      @model_class_name || name.underscore.gsub(/_controller$/, '').singularize
    end

  end

  module InstanceMethods
  end

end
