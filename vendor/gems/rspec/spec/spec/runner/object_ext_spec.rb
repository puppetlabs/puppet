require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe "ObjectExt" do
      it "should add copy_instance_variables_from to object" do
        Object.new.should respond_to(:copy_instance_variables_from)
      end
    end
  end
end
