module ResponderController
  # Configure how the controller finds and serves models of what flavor.
  module ClassMethods
    # The underscored, fully-qualified name of the served model class.
    #
    # By default, it is the underscored controller class name, without
    # +_controller+.
    def model_class_name
      @model_class_name || \
        name.underscore.gsub(/_controller$/, '').singularize
    end

    # Declare the underscored, fully-qualified name of the served model class.
    #
    # Modules are declared with separating slashes, such as in
    # <tt>admin/setting</tt>.  Strings or symbols are accepted, but other
    # values (including actual classes) will raise <tt>ArgumentError</tt>s.
    def serves_model(model_class_name)
      unless model_class_name.is_a? String or model_class_name.is_a? Symbol
        raise ArgumentError.new "Model must be a string or symbol"
      end

      @model_class_name = model_class_name.to_s
    end

    # Declare what active record scopes to allow or forbid to requests.
    #
    # .serves_scopes follows the regular :only/:except form:  white-listed
    # scopes are passed by name as <tt>:only => [:allowed, :scopes]</tt> or
    # <tt>:only => :just_one</tt>.  Similarly, black-listed ones are passed
    # under <tt>:except</tt>.
    #
    # If a white-list is passed, all other requested scopes (i.e. scopes named
    # by query parameters) will be denied, raising <tt>ForbiddenScope</tt>.
    # If a black-list is passed, only they will raise the exception.
    def serves_scopes(options = nil)
      @serves_scopes ||= {}

      if options
        raise TypeError unless options.is_a? Hash

        new_keys = @serves_scopes.keys | options.keys
        unless new_keys == [:only] or new_keys == [:except]
          raise ArgumentError.new(
            "serves_scopes takes exactly one of :only and :except")
        end

        @serves_scopes[options.keys.first] ||= []
        @serves_scopes[options.keys.first].concat [*options.values.first]
      end

      @serves_scopes
    end

    # Declare leading arguments ("responder context") for +#respond_with+.
    #
    # +respond_with+ creates urls from models.  To avoid strongly coupling
    # models to a url structure, it can take any number of leading parameters
    # a la +#polymorphic_url+.  +#responds_within+ declares these leading
    # parameters, to be used on each +respond_with+ call.
    #
    # It takes either a varargs or a block, but not both.  In
    # InstanceMethods#respond_with_contextual, the blocks are called with
    # +#instance_exec+, taking the model (or models) as a parameter.  They
    # should return an array.
    def responds_within(*args, &block)
      if block and args.any?
        raise ArgumentError.new(
          "responds_within can take arguments or a block, but not both")
      elsif block or args.any?
        @responds_within ||= []
        if not args.empty?
          @responds_within.concat args
        else
          @responds_within << block
        end
      end

      @responds_within || \
        model_class_name.split('/')[0...-1].collect { |m| m.to_sym }
    end

    # The served model class, identified by #model_class_name.
    def model_class
      model_class_name.camelize.constantize
    end

    # Declare a class-level scope for model collections.
    #
    # The model class is expected to respond to +all+, returning an Enumerable
    # of models.  Declared scopes are applied to (and replace) this
    # collection, suitable for active record scopes.
    #
    # It takes one of a string, symbol or block.  Symbols and strings are
    # called as methods on the collection without arguments.  Blocks are
    # called with +#instance_exec+ taking the current, accumulated query and
    # returning the new, scoped one.
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
    # <tt>children_of 'accounts/user'</tt> implies a scope and some responder
    # context.  The scope performs an ActiveRecord
    # <tt>where :user_id => params[:user_id]</tt>.  The responder context is a
    # call to <tt>#responds_within</tt> declaring the parent model's modules
    # along with the parent itself, found with
    # <tt>Accounts::User.find(params[:user_id])</tt>.
    def children_of(parent_model_class_name)
      parent_model_class_name = parent_model_class_name.to_s.underscore

      parent_name_parts = parent_model_class_name.split('/')
      parent_modules = parent_name_parts[0...-1].collect(&:to_sym)
      parent_id = "#{parent_name_parts.last}_id".to_sym # TODO: primary key

      scope do |query|
        query.where parent_id => params[parent_id]
      end

      responds_within do
        parent = parent_model_class_name.camelize.constantize.
          find params[parent_id]
        parent_modules + [parent]
      end
    end
  end
end
