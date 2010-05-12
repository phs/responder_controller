require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/module/delegation'

module ResponderController
  def self.included(mod)
    mod.extend ClassMethods
    mod.send :include, InstanceMethods
    mod.send :include, Actions
  end

  module ClassMethods
    def model_class_name
      @model_class_name || name.underscore.gsub(/_controller$/, '').singularize
    end

    def serves_model(model_class_name)
      unless model_class_name.is_a? String or model_class_name.is_a? Symbol
        raise ArgumentError.new "Model must be a string or symbol"
      end

      @model_class_name = model_class_name.to_s
    end

    def responds_within(*args, &block)
      if block and args.any?
        raise ArgumentError.new("responds_within can take arguments or a block, but not both")
      end

      @responds_within = args unless args.empty?
      @responds_within = block if block
      @responds_within || model_class_name.split('/')[0...-1].collect { |m| m.to_sym }
    end

    def model_class
      model_class_name.camelize.constantize
    end

    def scope(*args, &block)
      scope = args.first || block

      scope = scope.to_sym if String === scope
      unless scope.is_a? Symbol or scope.is_a? Proc
        raise ArgumentError.new "Scope must be a string, symbol or block"
      end

      (@scopes ||= []) << scope
    end

    attr_reader :scopes
  end

  module InstanceMethods
    delegate :model_class_name, :model_class, :scopes, :responds_within, :to => "self.class"

    def scope(query)
      query = (scopes || []).inject(query) do |query, scope|
        if Symbol === scope and model_class.scopes.key? scope
          query.send scope
        elsif Proc === scope
          instance_exec query, &scope
        else
          raise ArgumentError.new "Unknown scope #{model_class}.#{scope}"
        end
      end

      scopes_from_request = (model_class.scopes.keys & params.keys.collect { |k| k.to_sym })
      query = scopes_from_request.inject(query) do |query, scope|
        query.send scope, *params[scope.to_s]
      end

      query
    end

    def find_models
      scope model_class.all
    end

    def find_model
      find_models.first(params[:id])
    end

    def model_slug
      model_class_name.split('/').last.to_sym
    end

    def models_slug
      model_slug.to_s.pluralize.to_sym
    end

    def model_ivar
      "@#{model_slug}"
    end

    def models_ivar
      model_ivar.pluralize
    end

    def models
      instance_variable_get models_ivar
    end

    def models=(models)
      instance_variable_set models_ivar, models
    end

    def model
      instance_variable_get model_ivar
    end

    def model=(model)
      instance_variable_set model_ivar, model
    end

    def responder_context(model)
      context = responds_within
      context = instance_exec model, &context if context.is_a? Proc
      [*context] + [model]
    end

    def respond_with_contextual(model)
      respond_with responder_context(model)
    end
  end

  module Actions
    def index
      self.models = find_models
      respond_with_contextual models
    end

    def show
      self.model = find_model
      respond_with_contextual model
    end

    def new
      self.model = find_models.new
      respond_with_contextual model
    end

    def edit
      self.model = find_model
      respond_with_contextual model
    end

    def create
      self.model = find_models.new(params[model_slug])
      model.save
      respond_with_contextual model
    end

    def update
      self.model = find_model
      model.update_attributes(params[model_slug])
      respond_with_contextual model
    end

    def destroy
      find_model.destroy
      respond_with_contextual models_slug
    end
  end
end
