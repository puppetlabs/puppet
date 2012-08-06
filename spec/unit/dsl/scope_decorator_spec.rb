require 'spec_helper'

require 'puppet/dsl/scope_decorator'

describe Puppet::DSL::ScopeDecorator do
  let(:scope)   { mock "Scope" }
  let(:subject) { Puppet::DSL::ScopeDecorator }

  it "should raise ArgumentError when initializing without scope" do
    lambda { subject.new(nil) }.should raise_error ArgumentError
  end

  it "should allow accessing scope variables" do
    scope.expects(:[]).with('foo').returns 42
    subject.new(scope)['foo'].should == 42
  end

  it "should allow setting scope variables" do
    scope.expects(:[]=).with('foo', 42)
    subject.new(scope)['foo'] = 42
  end

  it "should stringify keys when accessing variables" do
    key = mock
    key.expects(:to_s).twice.returns "key"

    scope.expects(:[]).with key.to_s
    subject.new(scope)[key]
  end

  it "should stringify keys when setting variables" do
    key = mock
    key.expects(:to_s).twice.returns "key"

    scope.expects(:[]=).with key.to_s, 42
    subject.new(scope)[key] = 42
  end

end

