require 'active_support/core_ext/module/delegation'

module ResponderController
  # Instance methods that support the Actions module.
  module InstanceMethods
    delegate :model_class_name, :model_class, :scopes, :responds_within,
      :serves_scopes, :to => "self.class"

    # Apply scopes to the given query.
    #
    # Applicable scopes come from two places.  They are either declared at the
    # class level with <tt>ClassMethods#scope</tt>, or named in the request
    # itself.  The former is good for defining topics or enforcing security,
    # while the latter is free slicing and dicing for clients.
    #
    # Class-level scopes are applied first.  Request scopes come after, and
    # are discovered by examining +params+.  If any +params+ key matches a
    # name found in <tt>ClassMethods#model_class.scopes.keys</tt>, then it is
    # taken to be a scope and is applied.  The values under that +params+ key
    # are passed along as arguments.
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

      requested = model_class.scopes.keys & params.keys.collect(&:to_sym)

      if serves_scopes[:only] && (requested - serves_scopes[:only]).any?
        raise ForbiddenScope
      end

      if serves_scopes[:except] && (requested & serves_scopes[:except]).any?
        raise ForbiddenScope
      end

      query = requested.inject(query) do |query, scope|
        query.send scope, *params[scope.to_s] rescue raise BadScope
      end

      query
    end

    # Find all models in #scope.
    #
    # The initial query is <tt>ClassMethods#model_class.scoped</tt>.
    def find_models
      scope model_class.scoped
    end

    # Find a particular model.
    #
    # #find_models is asked to find a model with <tt>params[:id]</tt>.  This
    # ensures that class-level scopes are enforced (potentially for security.)
    def find_model
      models = find_models
      finder = models.respond_to?(:from_param) ? :from_param : :find
      models.send finder, params[:id]
    end

    # The underscored model class name, as a symbol.
    #
    # Model modules are omitted.
    def model_slug
      model_class_name.split('/').last.to_sym
    end

    # Like #model_slug, but plural.
    def models_slug
      model_slug.to_s.pluralize.to_sym
    end

    # The name of the instance variable holding a single model instance.
    def model_ivar
      "@#{model_slug}"
    end

    # The name of the instance variable holding a collection of models.
    def models_ivar
      model_ivar.pluralize
    end

    # Retrive #models_ivar
    def models
      instance_variable_get models_ivar
    end

    # Assign #models_ivar
    def models=(models)
      instance_variable_set models_ivar, models
    end

    # Retrive #model_ivar
    def model
      instance_variable_get model_ivar
    end

    # Assign #model_ivar
    def model=(model)
      instance_variable_set model_ivar, model
    end

    # Apply ClassMethods#responds_within to the given model (or symbol.)
    #
    # "Apply" just means turning +responds_within+ into an array and appending
    # +model+ to the end.  If +responds_within+ is an array, it used directly.
    #
    # If it is a proc, it is called with +instance_exec+, passing +model+ in.
    # It should return an array, which +model+ will be appended to.  (So,
    # don't include it in the return value.)
    def responder_context(model)
      context = responds_within.collect do |o|
        o = instance_exec model, &o if o.is_a? Proc
        o
      end.flatten + [model]
    end

    # Pass +model+ through InstanceMethods#responder_context, and pass that to
    # #respond_with.
    def respond_with_contextual(model)
      respond_with *responder_context(model)
    end
  end
end
