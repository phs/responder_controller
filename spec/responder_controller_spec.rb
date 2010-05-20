require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

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

describe "ResponderController" do

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

  describe '#model_class_name' do
    it "is .model_class_name" do
      PostsController.new.model_class_name.should == PostsController.model_class_name
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

  describe '#scope', 'by default' do
    it "passes its argument out" do
      PostsController.new.scope(@query).should == @query
    end
  end

  describe '#model_class' do
    it 'is .model_class' do
      PostsController.new.model_class.should == PostsController.model_class
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

  describe '#scopes' do
    it 'is .scopes' do
      PostsController.new.scopes.should == PostsController.scopes
    end
  end

  describe '#scope', 'with explicit scopes' do
    it "asks model_class for the declared scopes in order" do
      @query.should_receive(:unpublished).and_return(@query)
      @query.should_receive(:recent).and_return(@query)
      PostsController.new.scope(@query).should == @query
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

  describe '#scope', 'with a block scope' do
    it 'instance_execs the block while passing in the current query' do
      @query.should_receive(:owned_by).with('me').and_return(@query)

      controller = PostsController.new
      controller.scope(@query).should == @query
    end
  end

  describe '#scope', 'with an unknown scope' do
    it 'explodes' do
      PostsController.scope :furst_p0sts

      lambda do
        PostsController.new.scope
      end.should raise_error ArgumentError

      PostsController.scopes.pop
    end
  end

  describe '#scope', 'with request parameters naming scopes' do
    before :each do
      @controller = PostsController.new
      @controller.params['commented_on_by'] = 'you'
    end

    it 'applies the requested scopes in order' do
      @query.should_receive(:commented_on_by).with('you').and_return(@query)
      @controller.scope @query
    end

    it 'is applied after class-level scopes' do
      class_level_query = mock("class-level scoped query")
      @query.should_receive(:owned_by).and_return(class_level_query) # last class-level scope

      class_level_query.should_receive(:commented_on_by).with('you').and_return(class_level_query)
      @controller.scope(@query).should == class_level_query
    end

    it 'throws BadScope for scopes that raise an exception' do
      @query.should_receive(:commented_on_by).and_raise(ArgumentError.new)
      lambda do
        @controller.scope @query
      end.should raise_error(ResponderController::BadScope)
    end
  end

  describe '#find_models' do
    it 'is #scope #model_class.scoped' do
      controller = PostsController.new

      Post.should_receive(:scoped).and_return(@query)
      controller.should_receive(:scope).with(@query).and_return(@query)

      controller.find_models.should == @query
    end
  end

  describe '#find_model' do
    it 'is #find_models.find(params[:id])' do
      controller = PostsController.new
      controller.should_receive(:find_models).and_return(@query)
      @query.should_receive(:find).with(controller.params[:id]).and_return(post = mock("the post"))

      controller.find_model.should == post
    end
  end

  describe '#model_slug' do
    it 'is the model class name' do
      PostsController.new.model_slug.should == :post
    end

    it 'drops the leading module names, if any' do
      Admin::SettingsController.new.model_slug.should == :setting
    end
  end

  describe '#models_slug' do
    it 'is ths symbolized plural of #model_slug' do
      PostsController.new.models_slug.should == :posts
    end
  end

  describe '#model_ivar' do
    it 'is the #model_slug with a leading @' do
      PostsController.new.model_ivar.should == '@post'
    end
  end

  describe '#models_ivar' do
    it 'is the plural #model_ivar' do
      (controller = PostsController.new).models_ivar.should == controller.model_ivar.pluralize
    end
  end

  describe "#models" do
    it "gets #models_ivar" do
      (controller = PostsController.new).instance_variable_set("@posts", :some_posts)
      controller.models.should == :some_posts
    end
  end

  describe "#model" do
    it "gets #model_ivar" do
      (controller = PostsController.new).instance_variable_set("@post", :a_post)
      controller.model.should == :a_post
    end
  end

  describe "#models=" do
    it "assigns to #models_ivar" do
      assigned = mock("some models")
      (controller = PostsController.new).models = assigned
      controller.instance_variable_get("@posts").should == assigned
    end
  end

  describe "#model=" do
    it "assigns to #model_ivar" do
      assigned = mock("a model")
      (controller = PostsController.new).model = assigned
      controller.instance_variable_get("@post").should == assigned
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

  describe '#responds_within' do
    it 'is .responds_within' do
      PostsController.new.responds_within.should == PostsController.responds_within
    end
  end

  describe '#responder_context' do
    it "is the argument prepended with responds_within" do
      Admin::SettingsController.new.responder_context(:argument).should == [:admin, :argument]
    end

    it "passes the argument to responds_within and prepends the result if it is a lambda" do
      Admin::SettingsController.responds_within do |model|
        model.should == :argument
        [:nested, :namespace]
      end

      Admin::SettingsController.new.responder_context(:argument).should == [:nested, :namespace, :argument]
    end

    it "wraps the lambda result in an array if needed" do
      Admin::SettingsController.responds_within { |model| :namespace }
      Admin::SettingsController.new.responder_context(:argument).should == [:namespace, :argument]
    end

    after :each do
      Admin::SettingsController.instance_variable_set "@responds_within", nil
    end
  end

  describe '#respond_with_contextual' do
    it 'passed #responder_context to #respond_with' do
      controller = PostsController.new
      controller.should_receive(:responder_context).with(:argument).and_return([:contextualized_argument])
      controller.should_receive(:respond_with).with(:contextualized_argument)

      controller.respond_with_contextual :argument
    end
  end

  describe 'actions' do
    before :each do
      @controller = PostsController.new
      @controller.stub!(:find_models).and_return(@posts = mock("some posts"))
      @controller.stub!(:find_model).and_return(@post = mock("a post"))
      @controller.stub!(:respond_with)

      @posts.stub!(:build).and_return(@post)
    end

    describe '#index' do
      it 'assigns #find_models to #models=' do
        @controller.should_receive(:find_models).and_return(@posts)
        @controller.index
        @controller.instance_variable_get('@posts').should == @posts
      end

      it '#respond_with_contextual @models' do
        @controller.should_receive(:respond_with_contextual).with(@posts)
        @controller.index
      end
    end

    [:show, :edit].each do |verb|
      describe "##{verb}" do
        it 'assigns #find_model to #model=' do
          @controller.should_receive(:find_model).and_return(@post)
          @controller.send verb
          @controller.instance_variable_get('@post').should == @post
        end

        it '#respond_with_contextual @model' do
          @controller.should_receive(:respond_with_contextual).with(@post)
          @controller.send verb
        end
      end
    end

    describe '#new' do
      it 'assigns #find_models.new to #model=' do
        @posts.should_receive(:build).and_return(@post)
        @controller.new
        @controller.instance_variable_get('@post').should == @post
      end

      it '#respond_with_contextual @model' do
        @controller.should_receive(:respond_with_contextual).with(@post)
        @controller.new
      end
    end

    describe '#create' do
      before :each do
        @post.stub!(:save)
      end

      it 'passes params[model_slug] to #find_models.new' do
        @controller.params[:post] = :params_to_new
        @posts.should_receive(:build).with(:params_to_new)
        @controller.create
      end

      it 'assigns #find_models.new to #model=' do
        @controller.create
        @controller.instance_variable_get('@post').should == @post
      end

      it 'saves the model' do
        @post.should_receive(:save)
        @controller.create
      end

      it '#respond_with_contextual @model' do
        @controller.should_receive(:respond_with_contextual).with(@post)
        @controller.create
      end
    end

    describe '#update' do
      before :each do
        @post.stub!(:update_attributes)
      end

      it 'assigns #find_model to #model=' do
        @controller.should_receive(:find_model).and_return(@post)
        @controller.update
        @controller.instance_variable_get('@post').should == @post
      end

      it "updates the model's attributes" do
        @controller.params[:post] = :params_to_update
        @post.should_receive(:update_attributes).with(:params_to_update)
        @controller.update
      end

      it '#respond_with_contextual @model' do
        @controller.should_receive(:respond_with_contextual).with(@post)
        @controller.update
      end
    end

    describe '#destroy' do
      before :each do
        @post.stub!(:destroy)
      end

      it 'finds the model' do
        @controller.should_receive(:find_model).and_return(@post)
        @controller.destroy
      end

      it 'destroys the model' do
        @post.should_receive(:destroy)
        @controller.destroy
      end

      it '#respond_with_contextual #models_slug' do
        @controller.should_receive(:respond_with_contextual).with(:posts)
        @controller.destroy
      end
    end
  end
end
