require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "calling :should_receive with an options hash" do
      it "should report the file and line submitted with :expected_from" do
        spec = Spec::DSL::Example.new "spec" do
          mock = Spec::Mocks::Mock.new("a mock")
          mock.should_receive(:message, :expected_from => "/path/to/blah.ext:37")
          mock.rspec_verify
        end
        reporter = mock("reporter", :null_object => true)
        reporter.should_receive(:example_finished) do |spec, error|
          error.backtrace.detect {|line| line =~ /\/path\/to\/blah.ext:37/}.should_not be_nil
        end
        spec.run(reporter, nil, nil, nil, Object.new)
      end

      it "should use the message supplied with :message" do
        spec = Spec::DSL::Example.new "spec" do
          mock = Spec::Mocks::Mock.new("a mock")
          mock.should_receive(:message, :message => "recebi nada")
          mock.rspec_verify
        end
        reporter = mock("reporter", :null_object => true)
        reporter.should_receive(:example_finished) do |spec, error|
          error.message.should == "recebi nada"
        end
        spec.run(reporter, nil, nil, nil, Object.new)
      end
    end
  end
end
