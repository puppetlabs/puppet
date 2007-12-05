require File.dirname(__FILE__) + '/../../spec_helper.rb'
unless [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM}
  require 'spec/runner/heckle_runner'

  module Foo
    class Bar
      def one; end
      def two; end
    end

    class Zap
      def three; end
      def four; end
    end
  end

  describe "HeckleRunner" do
    before(:each) do
      @heckle = mock("heckle", :null_object => true)
      @behaviour_runner = mock("behaviour_runner")
      @heckle_class = mock("heckle_class")
    end

    it "should heckle all methods in all classes in a module" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "one", behaviour_runner).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", behaviour_runner).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Zap", "three", behaviour_runner).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Zap", "four", behaviour_runner).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo", @heckle_class)
      heckle_runner.heckle_with(behaviour_runner)
    end

    it "should heckle all methods in a class" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "one", behaviour_runner).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", behaviour_runner).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bar", @heckle_class)
      heckle_runner.heckle_with(behaviour_runner)
    end

    it "should fail heckling when the class is not found" do
      lambda do
        heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bob", @heckle_class)
        heckle_runner.heckle_with(behaviour_runner)
      end.should raise_error(StandardError, "Heckling failed - \"Foo::Bob\" is not a known class or module")
    end

    it "should heckle specific method in a class (with #)" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", behaviour_runner).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bar#two", @heckle_class)
      heckle_runner.heckle_with(behaviour_runner)
    end

    it "should heckle specific method in a class (with .)" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", behaviour_runner).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bar.two", @heckle_class)
      heckle_runner.heckle_with(behaviour_runner)
    end
  end
end
