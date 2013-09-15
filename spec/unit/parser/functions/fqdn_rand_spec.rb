#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/scope'

describe "the fqdn_rand function" do
  include PuppetSpec::Scope
  
  it "provides a random number strictly less than the given max" do
    fqdn_rand(3).should satisfy {|n| n.to_i < 3 }
  end

  it "provides the same 'random' value on subsequent calls for the same host" do
    fqdn_rand(3).should eql(fqdn_rand(3))
  end

  it "considers the same host and same extra arguments to have the same random sequence" do
    first_random = fqdn_rand(3, :extra_identifier => [1, "same", "host"])
    second_random = fqdn_rand(3, :extra_identifier => [1, "same", "host"])

    first_random.should eql(second_random)
  end

  it "allows extra arguments to control the random value on a single host" do
    first_random = fqdn_rand(10000, :extra_identifier => [1, "different", "host"])
    second_different_random = fqdn_rand(10000, :extra_identifier => [2, "different", "host"])

    first_random.should_not eql(second_different_random)
  end

  it "should return different sequences of value for different hosts" do
    val1 = fqdn_rand(1000000000, :host => "first.host.com")
    val2 = fqdn_rand(1000000000, :host => "second.host.com")

    val1.should_not eql(val2)
  end

  def fqdn_rand(max, args = {})
    host = args[:host] || '127.0.0.1'
    extra = args[:extra_identifier] || []

    scope = create_test_scope_for_node('localhost')
    scope.stubs(:[]).with("::fqdn").returns(host)

    scope.function_fqdn_rand([max] + extra)
  end
end
