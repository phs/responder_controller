module ResponderController
  # The seven standard restful actions.
  module Actions
    # Find, assign and respond with models.to_a.
    def index
      self.models = find_models
      respond_with_contextual models.to_a
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