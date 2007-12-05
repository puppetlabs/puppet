require File.dirname(__FILE__) + '/../../spec_helper.rb'

# NOTE - this was initially handled by an explicit matcher, but is now
# handled by a default set of predicate_matchers.

class Substance
  def initialize exists, description
    @exists = exists
    @description = description
  end
  def exist?
    @exists
  end
  def inspect
    @description
  end
end
  
describe "should exist" do
  before(:each) do
    @real = Substance.new true, 'something real'
    @imaginary = Substance.new false, 'something imaginary'
  end
  
  it "should pass if target exists" do
    @real.should exist
  end
  
  it "should fail if target does not exist" do
    lambda { @imaginary.should exist }.
      should fail
  end
end

describe "should_not exist" do  
  before(:each) do
    @real = Substance.new true, 'something real'
    @imaginary = Substance.new false, 'something imaginary'
  end
  it "should pass if target doesn't exist" do
    @imaginary.should_not exist
  end
  it "should fail if target does exist" do
    lambda { @real.should_not exist }.
      should fail
  end
end
    
