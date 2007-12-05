require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    describe Configuration do
      before(:each) do
        @config = Configuration.new
        @behaviour = mock("behaviour")
      end

      it "should default mock framework to rspec" do
        @config.mock_framework.should =~ /\/plugins\/mock_frameworks\/rspec$/
      end

      it "should let you set rspec mocking explicitly" do
        @config.mock_with(:rspec)
        @config.mock_framework.should =~ /\/plugins\/mock_frameworks\/rspec$/
      end

      it "should let you set mocha" do
        @config.mock_with(:mocha)
        @config.mock_framework.should =~ /\/plugins\/mock_frameworks\/mocha$/
      end

      it "should let you set flexmock" do
        @config.mock_with(:flexmock)
        @config.mock_framework.should =~ /\/plugins\/mock_frameworks\/flexmock$/
      end

      it "should let you set rr" do
        @config.mock_with(:rr)
        @config.mock_framework.should =~ /\/plugins\/mock_frameworks\/rr$/
      end
      
      it "should let you set an arbitrary adapter module" do
        adapter = Module.new
        @config.mock_with(adapter)
        @config.mock_framework.should == adapter
      end
      
      it "should let you define modules to be included" do
        mod = Module.new
        @config.include mod
        @config.modules_for(nil).should include(mod)
      end
      
      [:prepend_before, :append_before, :prepend_after, :append_after].each do |m|
        it "should delegate ##{m} to Behaviour class" do
          Behaviour.should_receive(m).with(:whatever)
          @config.__send__(m, :whatever)
        end
      end
    end
  end
end
