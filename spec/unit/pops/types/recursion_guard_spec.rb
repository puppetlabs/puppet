require 'spec_helper'
require 'puppet/pops/types/recursion_guard'

module Puppet::Pops::Types
describe 'the RecursionGuard' do
  let(:guard) { RecursionGuard.new }

  it "should detect recursion in 'this' context" do
    x = Object.new
    expect(guard.add_this(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
    expect(guard.add_this(x)).to eq(RecursionGuard::SELF_RECURSION_IN_THIS)
  end

  it "should detect recursion in 'that' context" do
    x = Object.new
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
    expect(guard.add_that(x)).to eq(RecursionGuard::SELF_RECURSION_IN_THAT)
  end

  it "should keep 'this' and 'that' context separate" do
    x = Object.new
    expect(guard.add_this(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
  end

  it "should detect when there's a recursion in both 'this' and 'that' context" do
    x = Object.new
    y = Object.new
    expect(guard.add_this(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
    expect(guard.add_that(y)).to eq(RecursionGuard::NO_SELF_RECURSION)
    expect(guard.add_this(x)).to eq(RecursionGuard::SELF_RECURSION_IN_THIS)
    expect(guard.add_that(y)).to eq(RecursionGuard::SELF_RECURSION_IN_BOTH)
  end

  it "should report that 'this' is recursive after a recursion has been detected" do
    x = Object.new
    guard.add_this(x)
    guard.add_this(x)
    expect(guard.recursive_this?(x)).to be_truthy
  end

  it "should report that 'that' is recursive after a recursion has been detected" do
    x = Object.new
    guard.add_that(x)
    guard.add_that(x)
    expect(guard.recursive_that?(x)).to be_truthy
  end

  it "should not report that 'this' is recursive after a recursion of 'that' has been detected" do
    x = Object.new
    guard.add_that(x)
    guard.add_that(x)
    expect(guard.recursive_this?(x)).to be_falsey
  end

  it "should not report that 'that' is recursive after a recursion of 'this' has been detected" do
    x = Object.new
    guard.add_that(x)
    guard.add_that(x)
    expect(guard.recursive_this?(x)).to be_falsey
  end

  it "should not call 'hash' on an added instance" do
    x = mock
    x.expects(:hash).never
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
  end

  it "should not call '==' on an added instance" do
    x = mock
    x.expects(:==).never
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
  end

  it "should not call 'eq?' on an added instance" do
    x = mock
    x.expects(:eq?).never
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
  end

  it "should not call 'eql?' on an added instance" do
    x = mock
    x.expects(:eql?).never
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
  end

  it "should not call 'equal?' on an added instance" do
    x = mock
    x.expects(:equal?).never
    expect(guard.add_that(x)).to eq(RecursionGuard::NO_SELF_RECURSION)
  end
end
end