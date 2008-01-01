require File.dirname(__FILE__) + '/../../spec_helper.rb'
unless [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM}
  require 'spec/runner/heckle_runner'

  describe "Heckler" do
    it "should run behaviour_runner on tests_pass?" do
      behaviour_runner = mock("behaviour_runner")
      behaviour_runner.should_receive(:run).with([], false)
      heckler = Spec::Runner::Heckler.new('Array', 'push', behaviour_runner)

      heckler.tests_pass?
    end
  end
end
