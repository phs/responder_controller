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

describe ResponderController::InstanceMethods do

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

    @controller = PostsController.new
  end

  describe '#model_class_name' do
    it "is .model_class_name" do
      @controller.model_class_name.should == PostsController.model_class_name
    end
  end

  describe '#model_class' do
    it 'is .model_class' do
      @controller.model_class.should == PostsController.model_class
    end
  end

  describe '#scopes' do
    it 'is .scopes' do
      @controller.scopes.should == PostsController.scopes
    end
  end

  describe '#scope' do
    it "passes its argument out by default" do
      @controller.scope(@query).should == @query
    end

    it "sends explicit, declared scopes to the query in order" do
      PostsController.scope :unpublished
      PostsController.scope :recent

      @query.should_receive(:unpublished).and_return(@query)
      @query.should_receive(:recent).and_return(@query)
      @controller.scope(@query).should == @query
    end

    it '#instance_execs block scopes, passing in the query' do
      PostsController.scope do |posts|
        posts.owned_by(params[:user_id])
      end

      @query.should_receive(:owned_by).with('me').and_return(@query)

      @controller.scope(@query).should == @query
    end

    it 'explodes with an unknown scope' do
      PostsController.scope :furst_p0sts

      lambda do
        @controller.scope
      end.should raise_error ArgumentError

      PostsController.scopes.pop
    end

    context 'with request parameters naming scopes' do
      before :each do
        @controller.params['commented_on_by'] = 'you'
      end

      it 'applies the requested scopes in order' do
        @query.should_receive(:commented_on_by).with('you').and_return(@query)
        @controller.scope @query
      end

      it 'is applied after class-level scopes' do
        # owned_by is the last class-level scope
        class_level_query = mock("class-level scoped query")
        @query.should_receive(:owned_by).and_return(class_level_query)

        class_level_query.should_receive(:commented_on_by).
          with('you').and_return(class_level_query)

        @controller.scope(@query).should == class_level_query
      end

      it 'throws BadScope for scopes that raise an exception' do
        @query.should_receive(:commented_on_by).and_raise(ArgumentError.new)
        lambda do
          @controller.scope @query
        end.should raise_error(ResponderController::BadScope)
      end
    end
  end

  describe '#find_models' do
    it 'is #scope #model_class.scoped' do
      Post.should_receive(:scoped).and_return(@query)
      @controller.should_receive(:scope).with(@query).and_return(@query)

      @controller.find_models.should == @query
    end
  end

  describe '#find_model' do
    before :each do
      @post = mock("the post")
      @query.stub!(:respond_to?).with(:from_param).and_return(false)
    end

    it 'is #from_param(params[:id]) if #find_models responds to it' do
      @controller.should_receive(:find_models).and_return(@query)

      @query.should_receive(:respond_to?).with(:from_param).and_return(true)
      @query.should_receive(:from_param).
        with(@controller.params[:id]).
        and_return(@post)

      @controller.find_model.should == @post
    end

    it 'is #find_models.find(params[:id]) otherwise' do
      @controller.should_receive(:find_models).and_return(@query)

      @query.should_receive(:find).
        with(@controller.params[:id]).
        and_return(@post)

      @controller.find_model.should == @post
    end
  end

  describe '#model_slug' do
    it 'is the model class name' do
      @controller.model_slug.should == :post
    end

    it 'drops the leading module names, if any' do
      Admin::SettingsController.new.model_slug.should == :setting
    end
  end

  describe '#models_slug' do
    it 'is ths symbolized plural of #model_slug' do
      @controller.models_slug.should == :posts
    end
  end

  describe '#model_ivar' do
    it 'is the #model_slug with a leading @' do
      @controller.model_ivar.should == '@post'
    end
  end

  describe '#models_ivar' do
    it 'is the plural #model_ivar' do
      @controller.models_ivar.should == @controller.model_ivar.pluralize
    end
  end

  describe "#models" do
    it "gets #models_ivar" do
      @controller.instance_variable_set("@posts", :some_posts)
      @controller.models.should == :some_posts
    end
  end

  describe "#model" do
    it "gets #model_ivar" do
      @controller.instance_variable_set("@post", :a_post)
      @controller.model.should == :a_post
    end
  end

  describe "#models=" do
    it "assigns to #models_ivar" do
      assigned = mock("some models")
      @controller.models = assigned
      @controller.instance_variable_get("@posts").should == assigned
    end
  end

  describe "#model=" do
    it "assigns to #model_ivar" do
      assigned = mock("a model")
      @controller.model = assigned
      @controller.instance_variable_get("@post").should == assigned
    end
  end

  describe '#responds_within' do
    it 'is .responds_within' do
      @controller.responds_within.should == PostsController.responds_within
    end
  end

  describe '#responder_context' do
    it "is the argument prepended with responds_within" do
      Admin::SettingsController.new.responder_context(:argument).should == [
        :admin, :argument]
    end

    it "passes lambdas to responds_within and prepends the results" do
      Admin::SettingsController.responds_within do |model|
        model.should == :argument
        [:nested, :namespace]
      end

      Admin::SettingsController.new.responder_context(:argument).should == [
          :nested, :namespace, :argument]
    end

    it "wraps the lambda result in an array if needed" do
      Admin::SettingsController.responds_within { |model| :namespace }
      Admin::SettingsController.new.responder_context(:argument).should == [
        :namespace, :argument]
    end

    after :each do
      Admin::SettingsController.instance_variable_set "@responds_within", nil
    end
  end

  describe '#respond_with_contextual' do
    it 'passed #responder_context to #respond_with' do
      @controller.should_receive(:responder_context).
        with(:argument).and_return([:contextualized_argument])
      @controller.should_receive(:respond_with).with(:contextualized_argument)

      @controller.respond_with_contextual :argument
    end
  end
end
