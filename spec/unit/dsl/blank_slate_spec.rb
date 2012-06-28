require 'puppet/dsl/blank_slate'

describe Puppet::DSL::BlankSlate do

  it "should have only few methods defined" do
    # List of methods implemented in BasicObject in Ruby 1.9
    [:==, :equal?, :'!', :'!=',
     :instance_eval, :instance_exec,
     :__send__, :__id__].each do |m|
       lambda do
         Puppet::DSL::BlankSlate.new.__send__ m
       end.should_not raise_error NoMethodError
     end
  end


  it "should allow to refer to global constants without prefixing" do
    ANSWER = 42
    Puppet::DSL::BlankSlate.new.instance_eval do
      ::ANSWER.should == ANSWER
    end
  end

end

