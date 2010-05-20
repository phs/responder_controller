require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/module/delegation'

module ResponderController
  def self.included(mod)
    mod.extend ClassMethods
    mod.send :include, InstanceMethods
    mod.send :include, Actions
  end

  # Configure how the controller finds and serves models of what flavor.
  module ClassMethods
    # The underscored, fully-qualified name of the served model class.
    #
    # By default, it is the underscored controller class name, without +_controller+.
    def model_class_name
      @model_class_name || name.underscore.gsub(/_controller$/, '').singularize
    end

    # Declare the underscored, fully-qualified name of the served model class.
    #
    # Modules are declared with separating slashes, such as in <tt>admin/setting</tt>.  Strings
    # or symbols are accepted, but other values (including actual classes) will raise
    # <tt>ArgumentError</tt>s.
    def serves_model(model_class_name)
      unless model_class_name.is_a? String or model_class_name.is_a? Symbol
        raise ArgumentError.new "Model must be a string or symbol"
      end

      @model_class_name = model_class_name.to_s
    end

    # Declare leading arguments ("responder context") for +respond_with+ calls.
    #
    # +respond_with+ creates urls from models.  To avoid strongly coupling models to a url
    # structure, it can take any number of leading parameters a la +polymorphic_url+.
    # +responds_within+ declares these leading parameters, to be used on each +respond_with+ call.
    #
    # It takes either a varargs or a block, but not both.  In
    # InstanceMethods#respond_with_contextual, the blocks are called with +instance_exec+, taking
    # the model (or models) as a parameter.  They should return an array.
    def responds_within(*args, &block)
      if block and args.any?
        raise ArgumentError.new("responds_within can take arguments or a block, but not both")
      elsif block or args.any?
        @responds_within ||= []
        if not args.empty?
          @responds_within.concat args
        else
          @responds_within << block
        end
      end

      @responds_within || model_class_name.split('/')[0...-1].collect { |m| m.to_sym }
    end

    # The served model class, identified by #model_class_name.
    def model_class
      model_class_name.camelize.constantize
    end

    # Declare a class-level scope for model collections.
    #
    # The model class is expected to respond to +all+, returning an Enumerable of models.
    # Declared scopes are applied to (and replace) this collection, suitable for active record
    # scopes.
    #
    # It takes one of a string, symbol or block.  Symbols and strings are called as methods on the
    # collection without arguments.  Blocks are called with +instance_exec+ taking the current,
    # accumulated query and returning the new, scoped one.
    def scope(*args, &block)
      scope = args.first || block

      scope = scope.to_sym if String === scope
      unless scope.is_a? Symbol or scope.is_a? Proc
        raise ArgumentError.new "Scope must be a string, symbol or block"
      end

      (@scopes ||= []) << scope
    end

    # The array of declared class-level scopes, as symbols or procs.
    attr_reader :scopes

    # Declare a (non-singleton) parent resource class.
    #
    # <tt>children_of 'accounts/user'</tt> implies a scope and some responder context.  The scope
    # performs an ActiveRecord <tt>where :user_id => params[:user_id]</tt>.  The responder context
    # is a call to <tt>#responds_within</tt> declaring the parent model's modules along with the
    # parent itself, found with <tt>Accounts::User.find(params[:user_id])</tt>.
    def children_of(parent_model_class_name)
      parent_model_class_name = parent_model_class_name.to_s.underscore

      parent_name_parts = parent_model_class_name.split('/')
      parent_modules = parent_name_parts[0...-1].collect(&:to_sym)
      parent_id = "#{parent_name_parts.last}_id".to_sym

      scope do |query|
        query.where parent_id => params[parent_id]
      end

      responds_within do
        parent = parent_model_class_name.camelize.constantize.find params[parent_id]
        parent_modules + [parent]
      end
    end
  end

  # Instance methods that support the Actions module.
  module InstanceMethods
    delegate :model_class_name, :model_class, :scopes, :responds_within, :to => "self.class"

    # Apply scopes to the given query.
    #
    # Applicable scopes come from two places.  They are either declared at the class level with
    # <tt>ClassMethods#scope</tt>, or named in the request itself.  The former is good for
    # defining topics or enforcing security, while the latter is free slicing and dicing for
    # clients.
    #
    # Class-level scopes are applied first.  Request scopes come after, and are discovered by
    # examining +params+.  If any +params+ key matches a name found in
    # <tt>ClassMethods#model_class.scopes.keys</tt>, then it is taken to be a scope and is
    # applied.  The values under that +params+ key are passed along as arguments.
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

    # Find all models in #scope.
    #
    # The initial query is <tt>ClassMethods#model_class.scoped</tt>.
    def find_models
      scope model_class.scoped
    end

    # Find a particular model.
    #
    # #find_models is asked to find a model with <tt>params[:id]</tt>.  This ensures that
    # class-level scopes are enforced (potentially for security.)
    def find_model
      find_models.find(params[:id])
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
    # "Apply" just means turning +responds_within+ into an array and appending +model+ to the
    # end.  If +responds_within+ is an array, it used directly.
    #
    # If it is a proc, it is called with +instance_exec+, passing +model+ in.  It should return an
    # array, which +model+ will be appended to.  (So, don't include it in the return value.)
    def responder_context(model)
      context = responds_within.collect do |o|
        o = instance_exec model, &o if o.is_a? Proc
        o
      end.flatten + [model]
    end

    # Pass +model+ through InstanceMethods#responder_context, and pass that to #respond_with.
    def respond_with_contextual(model)
      respond_with *responder_context(model)
    end
  end

  # The seven standard restful actions.
  module Actions
    # Find, assign and respond with models.
    def index
      self.models = find_models
      respond_with_contextual models
    end

    # Find, assign and respond with a single model.
    def show
      self.model = find_model
      respond_with_contextual model
    end

    # Build (but do not save), assign and respond with a new model.
    #
    # The new model is built from the <tt>InstanceMethods#find_models</tt> collection, meaning it
    # could inherit any properties implied by those scopes.
    def new
      self.model = find_models.build
      respond_with_contextual model
    end

    # Find, assign and respond with a single model.
    def edit
      self.model = find_model
      respond_with_contextual model
    end

    # Build, save, assign and respond with a new model.
    #
    # The model is created with attributes from the request params, under the
    # <tt>InstanceMethods#model_slug</tt> key.
    def create
      self.model = find_models.build(params[model_slug])
      model.save
      respond_with_contextual model
    end

    # Find, update, assign and respond with a single model.
    #
    # The new attributes are taken from the request params, under the
    # <tt>InstanceMethods#model_slug</tt> key.
    def update
      self.model = find_model
      model.update_attributes(params[model_slug])
      respond_with_contextual model
    end

    # Find and destroy a model.  Respond with <tt>InstanceMethods#models_slug</tt>.
    def destroy
      find_model.destroy
      respond_with_contextual models_slug
    end
  end
end
