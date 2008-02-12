require File.dirname(__FILE__) + '/../../../spec_helper.rb'

describe Object, "#should" do
  before(:each) do
    @target = "target"
    @matcher = mock("matcher")
    @matcher.stub!(:matches?).and_return(true)
    @matcher.stub!(:failure_message)
  end
  
  it "should accept and interact with a matcher" do
    @matcher.should_receive(:matches?).with(@target).and_return(true)
    
    @target.should @matcher
  end
  
  it "should ask for a failure_message when matches? returns false" do
    @matcher.should_receive(:matches?).with(@target).and_return(false)
    @matcher.should_receive(:failure_message).and_return("the failure message")
    lambda {
      @target.should @matcher
    }.should fail_with("the failure message")
  end
end

describe Object, "#should_not" do
  before(:each) do
    @target = "target"
    @matcher = mock("matcher")
  end
  
  it "should accept and interact with a matcher" do
    @matcher.should_receive(:matches?).with(@target).and_return(false)
    @matcher.stub!(:negative_failure_message)
    
    @target.should_not @matcher
  end
  
  it "should ask for a negative_failure_message when matches? returns true" do
    @matcher.should_receive(:matches?).with(@target).and_return(true)
    @matcher.should_receive(:negative_failure_message).and_return("the negative failure message")
    lambda {
      @target.should_not @matcher
    }.should fail_with("the negative failure message")
  end
end
