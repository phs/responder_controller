require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'

module ResponderController
  autoload :ClassMethods, 'responder_controller/class_methods'
  autoload :InstanceMethods, 'responder_controller/instance_methods'
  autoload :Actions, 'responder_controller/actions'
  
  # Root of scope-related exceptions.
  class ScopeError < StandardError
  end

  # Raised when an active record scope itself raises an exception.
  #
  # If this exception bubbles up, rails will render it as a 400.
  class BadScope < ScopeError
  end

  # Raised when attempting to call a scope forbidden by ClassMethods.serves_scopes.
  #
  # If this exception bubbles up, rails will render it as a 403.
  class ForbiddenScope < ScopeError
  end

  def self.included(mod)
    mod.extend ClassMethods
    mod.send :include, InstanceMethods
    mod.send :include, Actions

    # Declare http statuses to return for uncaught scope errors.
    ActionDispatch::ShowExceptions.rescue_responses.update({
      BadScope.name => :bad_request,
      ForbiddenScope.name => :forbidden
    }) if defined? ActionDispatch
  end
end
