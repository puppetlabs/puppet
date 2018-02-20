#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/scope'

describe "the fqdn_rand function" do
  include PuppetSpec::Scope

  it "returns an integer" do
    expect(fqdn_rand(3)).to be_an(Integer)
  end

  it "provides a random number strictly less than the given max" do
    expect(fqdn_rand(3)).to satisfy {|n| n < 3 }
  end

  it "provides the same 'random' value on subsequent calls for the same host" do
    expect(fqdn_rand(3)).to eql(fqdn_rand(3))
  end

  it "considers the same host and same extra arguments to have the same random sequence" do
    first_random = fqdn_rand(3, :extra_identifier => [1, "same", "host"])
    second_random = fqdn_rand(3, :extra_identifier => [1, "same", "host"])

    expect(first_random).to eql(second_random)
  end

  it "allows extra arguments to control the random value on a single host" do
    first_random = fqdn_rand(10000, :extra_identifier => [1, "different", "host"])
    second_different_random = fqdn_rand(10000, :extra_identifier => [2, "different", "host"])

    expect(first_random).not_to eql(second_different_random)
  end

  it "should return different sequences of value for different hosts" do
    val1 = fqdn_rand(1000000000, :host => "first.host.com")
    val2 = fqdn_rand(1000000000, :host => "second.host.com")

    expect(val1).not_to eql(val2)
  end

  it "should return a specific value with given set of inputs on non-fips enabled host" do
    Puppet::Util::Platform.stubs(:fips_enabled?).returns false

    expect(fqdn_rand(3000, :host => 'dummy.fqdn.net')).to eql(338)
  end

  it "should return a specific value with given set of inputs on fips enabled host" do
    Puppet::Util::Platform.stubs(:fips_enabled?).returns true

    expect(fqdn_rand(3000, :host => 'dummy.fqdn.net')).to eql(278)
  end

  it "should return a specific value with given seed on a non-fips enabled host" do
    Puppet::Util::Platform.stubs(:fips_enabled?).returns false

    expect(fqdn_rand(5000, :extra_identifier => ['expensive job 33'])).to eql(3374)
  end

  it "should return a specific value with given seed on a fips enabled host" do
    Puppet::Util::Platform.stubs(:fips_enabled?).returns true

    expect(fqdn_rand(5000, :extra_identifier => ['expensive job 33'])).to eql(2389)
  end

  def fqdn_rand(max, args = {})
    host = args[:host] || '127.0.0.1'
    extra = args[:extra_identifier] || []

    scope = create_test_scope_for_node('localhost')
    scope.stubs(:[]).with("::fqdn").returns(host)

    scope.function_fqdn_rand([max] + extra)
  end
end
