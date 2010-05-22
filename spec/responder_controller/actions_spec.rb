require 'spec_helper'

describe ResponderController do

  class ApplicationController
    include ResponderController

    def params
      @params ||= { :user_id => 'me', :id => 7 }
    end
  end

  class PostsController < ApplicationController
  end

  describe ResponderController::Actions do
    before :each do
      @controller = PostsController.new
      @controller.stub!(:find_models).and_return(@posts = mock("some posts"))
      @controller.stub!(:find_model).and_return(@post = mock("a post"))
      @controller.stub!(:respond_with)

      @posts.stub!(:build).and_return(@post)
      @posts.stub!(:to_a).and_return([])
    end

    describe '#index' do
      it 'assigns #find_models to #models=' do
        @controller.should_receive(:find_models).and_return(@posts)
        @controller.index
        @controller.instance_variable_get('@posts').should == @posts
      end

      it '#respond_with_contextual @models.to_a' do
        @posts.should_receive(:to_a).and_return(:posts_array)
        @controller.should_receive(:respond_with_contextual).with(:posts_array)
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
