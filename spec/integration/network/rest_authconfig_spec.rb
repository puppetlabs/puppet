require 'spec_helper'

require 'puppet/network/rest_authconfig'

RSpec::Matchers.define :allow do |params|

  match do |auth|
    begin
      auth.check_authorization(params[0], params[1], params[2], params[3])
      true
    rescue Puppet::Network::AuthorizationError
      false
    end
  end

  failure_message_for_should do |instance|
    "expected #{params[3][:node]}/#{params[3][:ip]} to be allowed"
  end

  failure_message_for_should_not do |instance|
    "expected #{params[3][:node]}/#{params[3][:ip]} to be forbidden"
  end
end

describe Puppet::Network::RestAuthConfig do
  include PuppetSpec::Files

  before(:each) do
    Puppet[:rest_authconfig] = tmpfile('auth.conf')
  end

  def add_rule(rule)
    File.open(Puppet[:rest_authconfig],"w+") do |f|
      f.print "path /test\n#{rule}\n"
    end
    @auth = Puppet::Network::RestAuthConfig.new(Puppet[:rest_authconfig], true)
  end

  def add_regex_rule(regex, rule)
    File.open(Puppet[:rest_authconfig],"w+") do |f|
      f.print "path ~ #{regex}\n#{rule}\n"
    end
    @auth = Puppet::Network::RestAuthConfig.new(Puppet[:rest_authconfig], true)
  end

  def request(args = {})
    { :ip => '10.1.1.1', :node => 'host.domain.com', :key => 'key', :authenticated => true }.each do |k,v|
      args[k] ||= v
    end
    ['test', :find, args[:key], args]
  end

  it "should support IPv4 address" do
    add_rule("allow 10.1.1.1")

    @auth.should allow(request)
  end

  it "should support CIDR IPv4 address" do
    add_rule("allow 10.0.0.0/8")

    @auth.should allow(request)
  end

  it "should support wildcard IPv4 address" do
    add_rule("allow 10.1.1.*")

    @auth.should allow(request)
  end

  it "should support IPv6 address" do
    add_rule("allow 2001:DB8::8:800:200C:417A")

    @auth.should allow(request(:ip => '2001:DB8::8:800:200C:417A'))
  end

  it "should support hostname" do
    add_rule("allow host.domain.com")

    @auth.should allow(request)
  end

  it "should support wildcard host" do
    add_rule("allow *.domain.com")

    @auth.should allow(request)
  end

  it "should support hostname backreferences" do
    add_regex_rule('^/test/([^/]+)$', "allow $1.domain.com")

    @auth.should allow(request(:key => 'host'))
  end

  it "should support opaque strings" do
    add_rule("allow this-is-opaque@or-not")

    @auth.should allow(request(:node => 'this-is-opaque@or-not'))
  end

  it "should support opaque strings and backreferences" do
    add_regex_rule('^/test/([^/]+)$', "allow $1")

    @auth.should allow(request(:key => 'this-is-opaque@or-not', :node => 'this-is-opaque@or-not'))
  end

  it "should support hostname ending with '.'" do
    pending('bug #7589')
    add_rule("allow host.domain.com.")

    @auth.should allow(request(:node => 'host.domain.com.'))
  end

  it "should support hostname ending with '.' and backreferences" do
    pending('bug #7589')
    add_regex_rule('^/test/([^/]+)$',"allow $1")

    @auth.should allow(request(:node => 'host.domain.com.'))
  end

  it "should support trailing whitespace" do
    add_rule('allow host.domain.com    ')

    @auth.should allow(request)
  end

  it "should support inlined comments" do
    add_rule('allow host.domain.com # will it work?')

    @auth.should allow(request)
  end

  it "should deny non-matching host" do
    add_rule("allow inexistant")

    @auth.should_not allow(request)
  end

  it "should deny denied hosts" do
    add_rule("deny host.domain.com")

    @auth.should_not allow(request)
  end

end