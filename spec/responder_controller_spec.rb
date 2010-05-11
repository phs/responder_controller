require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Post

  class <<self
    def scopes
      {
        :recent => "a scope",
        :unpublished => "another"
      }
    end

    def recent; end
    def unpublished; end
    def find(id); end
  end

  def create(*args); end
  def update_attributes(*args); end
  def destroy; end

end

describe "ResponderController" do

  class ApplicationController
    include ResponderController
  end

  class PostsController < ApplicationController
  end

  module Admin
    class SettingsController < ApplicationController
    end
  end

  describe '.model_class_name', 'by default' do
    it 'is taken from the controller class name' do
      PostsController.model_class_name.should == 'post'
    end

    it "includes the controller's modules divided by whacks" do
      Admin::SettingsController.model_class_name.should == 'admin/setting'
    end
  end

end
