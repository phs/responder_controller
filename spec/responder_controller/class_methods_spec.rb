require 'spec_helper'

class Post
  class <<self
    def scopes
      {
        :recent => "a scope",
        :unpublished => "another",
        :authored_by => "and another",
        :commented_on_by => "even one more",
        :published_after => "man they just keep coming"
      }
    end
  end
end

module Accounts
  class User
  end
end

module Admin
  class Setting
  end
end

describe ResponderController::ClassMethods do

  class ApplicationController
    include ResponderController

    def params
      @params ||= { :user_id => 'me', :id => 7 }
    end
  end

  class PostsController < ApplicationController
  end

  class Admin::SettingsController < ApplicationController
  end

  before :each do
    @query = mock("the scoped query")
    @query.stub!(:unpublished).and_return(@query)
    @query.stub!(:recent).and_return(@query)
    @query.stub!(:owned_by).with('me').and_return(@query)
  end

  describe '.model_class_name', 'by default' do
    it 'is taken from the controller class name' do
      PostsController.model_class_name.should == 'post'
    end

    it "includes the controller's modules divided by whacks" do
      Admin::SettingsController.model_class_name.should == 'admin/setting'
    end
  end

  describe '.serves_model' do
    it 'sets the model class name to the passed value' do
      PostsController.serves_model 'some_other_model'
      PostsController.model_class_name.should == 'some_other_model'
    end

    it 'accepts symbols as well as strings' do
      PostsController.serves_model :some_other_model
      PostsController.model_class_name.should == 'some_other_model'
    end

    it 'raises ArgumentError for other values' do
      lambda do
        PostsController.serves_model [:not_a, :string_or_symbol]
      end.should raise_error ArgumentError
    end

    after :each do
      PostsController.serves_model :post
    end
  end

  describe '.model_class' do
    it 'is the constant named by model_class_name' do
      PostsController.model_class.should == Post
    end

    it 'handles modules in the name' do
      Admin::SettingsController.model_class.should == Admin::Setting
    end
  end

  describe '.scope' do
    it 'takes a string naming a scope on model_class' do
      PostsController.scope 'unpublished'
    end

    it 'can take a symbol' do
      PostsController.scope :recent
    end
  end

  describe '.scopes' do
    it 'is an array of scopes in order, as symbols' do
      PostsController.scopes.should == [:unpublished, :recent]
    end
  end

  describe '.scope', 'with a block' do
    it 'omits the name and can reference params' do
      PostsController.scope do |posts|
        posts.owned_by(params[:user_id])
      end
    end

    it 'puts a lambda on .scopes' do
      PostsController.scopes.last.should be_a Proc
    end
  end

  describe '.scope', 'with something that is not a string, symbol or block' do
    it 'explodes' do
      lambda do
        PostsController.scope [:not_a, :string_symbol_or_block]
      end.should raise_error ArgumentError
    end
  end

  describe '.serves_scopes' do
    before :each do
      @controller = PostsController.new
      @controller.params['commented_on_by'] = 'you'
    end

    it 'can specify a white list of active record scopes to serve' do
      PostsController.serves_scopes :only => [:recent, :authored_by, :published_after]
      lambda do
        @controller.scope @query
      end.should raise_error(ResponderController::ForbiddenScope)
    end

    it 'can specify just one scope to white list' do
      PostsController.serves_scopes :only => :recent
      lambda do
        @controller.scope @query
      end.should raise_error(ResponderController::ForbiddenScope)
    end

    it 'can specify a black list of active record scopes to deny' do
      PostsController.serves_scopes :except => [:commented_on_by, :unpublished]
      lambda do
        @controller.scope @query
      end.should raise_error(ResponderController::ForbiddenScope)
    end

    it 'can specify just one scope to black list' do
      PostsController.serves_scopes :except => :commented_on_by
      lambda do
        @controller.scope @query
      end.should raise_error(ResponderController::ForbiddenScope)
    end

    it 'whines if passed anything other than a hash' do
      lambda do
        PostsController.serves_scopes 'cupcakes!'
      end.should raise_error TypeError
    end

    it 'whines about keys other than :only and :except' do
      lambda do
        PostsController.serves_scopes 'only' => :recent
      end.should raise_error ArgumentError
    end

    it 'whines when both :only and :except are passed' do
      lambda do
        PostsController.serves_scopes :only => :recent, :except => :commented_on_by
      end.should raise_error ArgumentError
    end

    it 'whines if both :only and :except are passed between different calls' do
      PostsController.serves_scopes :only => :recent
      lambda do
        PostsController.serves_scopes :except => :commented_on_by
      end.should raise_error ArgumentError
    end

    it 'accumulates scopes passed over multiple calls' do
      PostsController.serves_scopes :only => :recent
      PostsController.serves_scopes :only => :authored_by
      PostsController.serves_scopes[:only].should == [:recent, :authored_by]
    end

    after :each do
      PostsController.serves_scopes.clear # clean up
    end
  end

  describe '.responds_within' do
    it "contains the model's enclosing module names as symbols by default" do
      PostsController.responds_within.should == []
      Admin::SettingsController.responds_within.should == [:admin]
    end

    it "takes, saves and returns a varargs" do
      PostsController.responds_within(:foo, :bar, :baz).should == [:foo, :bar, :baz]
      PostsController.responds_within.should == [:foo, :bar, :baz]
    end

    it "accumulates between calls" do
      PostsController.responds_within(:foo).should == [:foo]
      PostsController.responds_within(:bar, :baz).should == [:foo, :bar, :baz]
      PostsController.responds_within.should == [:foo, :bar, :baz]
    end

    it "can take a block instead" do
      block = lambda {}
      PostsController.responds_within(&block).should == [block]
      PostsController.responds_within.should == [block]
    end

    it "whines if both positional arguments and a block are passed" do
      lambda do
        PostsController.responds_within(:foo, :bar, :baz) {}
      end.should raise_error ArgumentError
    end

    after :each do
      PostsController.instance_variable_set "@responds_within", nil # clear out the garbage
    end
  end

  describe '.children_of' do
    it 'takes a underscored model class name' do
      PostsController.children_of 'accounts/user'
    end

    it "can take symbols" do
      PostsController.children_of 'accounts/user'.to_sym
    end

    it "creates a scope filtering by the parent model's foreign key as passed in params" do
      PostsController.children_of 'accounts/user'
      controller = PostsController.new
      controller.params[:user_id] = :the_user_id

      user_query = mock("user-restricted query")
      @query.should_receive(:where).with(:user_id => :the_user_id).and_return(user_query)
      controller.scope(@query).should == user_query
    end

    it "adds a responds_within context, of the parent modules followed by the parent itself" do
      PostsController.children_of 'accounts/user'
      controller = PostsController.new
      controller.params[:user_id] = :the_user_id

      Accounts::User.should_receive(:find).with(:the_user_id).and_return(user = mock("the user"))

      controller.responder_context(:argument).should == [:accounts, user, :argument]
    end

    after :each do
      PostsController.instance_variable_set "@responds_within", nil # clear out the garbage
      PostsController.scopes.clear
    end
  end
end
