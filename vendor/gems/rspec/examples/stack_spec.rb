require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + "/stack"

describe "non-empty Stack", :shared => true do
  # NOTE that this one auto-generates the description "should not be empty"
  it { @stack.should_not be_empty }
  
  it "should return the top item when sent #peek" do
    @stack.peek.should == @last_item_added
  end

  it "should NOT remove the top item when sent #peek" do
    @stack.peek.should == @last_item_added
    @stack.peek.should == @last_item_added
  end
  
  it "should return the top item when sent #pop" do
    @stack.pop.should == @last_item_added
  end
  
  it "should remove the top item when sent #pop" do
    @stack.pop.should == @last_item_added
    unless @stack.empty?
      @stack.pop.should_not == @last_item_added
    end
  end
end

describe "non-full Stack", :shared => true do
  # NOTE that this one auto-generates the description "should not be full"
  it { @stack.should_not be_full }

  it "should add to the top when sent #push" do
    @stack.push "newly added top item"
    @stack.peek.should == "newly added top item"
  end
end

describe Stack, " (empty)" do
  before(:each) do
    @stack = Stack.new
  end
  
  # NOTE that this one auto-generates the description "should be empty"
  it { @stack.should be_empty }
  
  it_should_behave_like "non-full Stack"
  
  it "should complain when sent #peek" do
    lambda { @stack.peek }.should raise_error(StackUnderflowError)
  end
  
  it "should complain when sent #pop" do
    lambda { @stack.pop }.should raise_error(StackUnderflowError)
  end
end

describe Stack, " (with one item)" do
  before(:each) do
    @stack = Stack.new
    @stack.push 3
    @last_item_added = 3
  end

  it_should_behave_like "non-empty Stack"
  it_should_behave_like "non-full Stack"

end

describe Stack, " (with one item less than capacity)" do
  before(:each) do
    @stack = Stack.new
    (1..9).each { |i| @stack.push i }
    @last_item_added = 9
  end
  
  it_should_behave_like "non-empty Stack"
  it_should_behave_like "non-full Stack"
end

describe Stack, " (full)" do
  before(:each) do
    @stack = Stack.new
    (1..10).each { |i| @stack.push i }
    @last_item_added = 10
  end

  # NOTE that this one auto-generates the description "should be full"
  it { @stack.should be_full }  

  it_should_behave_like "non-empty Stack"

  it "should complain on #push" do
    lambda { @stack.push Object.new }.should raise_error(StackOverflowError)
  end
  
end
