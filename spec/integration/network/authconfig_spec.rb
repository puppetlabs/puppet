require 'spec_helper'

require 'puppet/network/authconfig'
require 'puppet/network/auth_config_parser'

RSpec::Matchers.define :allow do |params|

  match do |auth|
    begin
      auth.check_authorization(*params)
      true
    rescue Puppet::Network::AuthorizationError
      false
    end
  end

  failure_message do |instance|
    "expected #{params[2][:node]}/#{params[2][:ip]} to be allowed"
  end

  failure_message_when_negated do |instance|
    "expected #{params[2][:node]}/#{params[2][:ip]} to be forbidden"
  end
end

describe Puppet::Network::AuthConfig do
  include PuppetSpec::Files

  def add_rule(rule)
    parser = Puppet::Network::AuthConfigParser.new(
      "path /test\n#{rule}\n"
    )
    @auth = parser.parse
  end

  def add_regex_rule(regex, rule)
    parser = Puppet::Network::AuthConfigParser.new(
      "path ~ #{regex}\n#{rule}\n"
    )
    @auth = parser.parse
  end

  def add_raw_stanza(stanza)
    parser = Puppet::Network::AuthConfigParser.new(
      stanza
    )
    @auth = parser.parse
  end

  def request(args = {})
    args = {
      :key => 'key',
      :node => 'host.domain.com',
      :ip => '10.1.1.1',
      :authenticated => true
    }.merge(args)
    [:find, "/test/#{args[:key]}", args]
  end

  describe "allow" do
    it "should not match IP addresses" do
      add_rule("allow 10.1.1.1")

      expect(@auth).not_to allow(request)
    end

    it "should not accept CIDR IPv4 address" do
      expect {
        add_rule("allow 10.0.0.0/8")
      }.to raise_error Puppet::ConfigurationError, /Invalid pattern 10\.0\.0\.0\/8/
    end

    it "should not match wildcard IPv4 address" do
      expect {
        add_rule("allow 10.1.1.*")
      }.to raise_error Puppet::ConfigurationError, /Invalid pattern 10\.1\.1\.*/
    end

    it "should not match IPv6 address" do
      expect {
        add_rule("allow 2001:DB8::8:800:200C:417A")
      }.to raise_error Puppet::ConfigurationError, /Invalid pattern 2001/
    end

    it "should support hostname" do
      add_rule("allow host.domain.com")

      expect(@auth).to allow(request)
    end

    it "should support wildcard host" do
      add_rule("allow *.domain.com")

      expect(@auth).to allow(request)
    end

    it 'should warn about missing path before allow_ip in stanza' do
      expect {
        add_raw_stanza("allow_ip 10.0.0.1\n")
      }.to raise_error Puppet::ConfigurationError, /Missing or invalid 'path' before right directive at \(line: .*\)/
    end

    it 'should warn about missing path before allow in stanza' do
      expect {
        add_raw_stanza("allow host.domain.com\n")
      }.to raise_error Puppet::ConfigurationError, /Missing or invalid 'path' before right directive at \(line: .*\)/
    end

    it "should support hostname backreferences" do
      add_regex_rule('^/test/([^/]+)$', "allow $1.domain.com")

      expect(@auth).to allow(request(:key => 'host'))
    end

    it "should support opaque strings" do
      add_rule("allow this-is-opaque@or-not")

      expect(@auth).to allow(request(:node => 'this-is-opaque@or-not'))
    end

    it "should support opaque strings and backreferences" do
      add_regex_rule('^/test/([^/]+)$', "allow $1")

      expect(@auth).to allow(request(:key => 'this-is-opaque@or-not', :node => 'this-is-opaque@or-not'))
    end

    it "should support hostname ending with '.'" do
      pending('bug #7589')
      add_rule("allow host.domain.com.")

      expect(@auth).to allow(request(:node => 'host.domain.com.'))
    end

    it "should support hostname ending with '.' and backreferences" do
      pending('bug #7589')
      add_regex_rule('^/test/([^/]+)$',"allow $1")

      expect(@auth).to allow(request(:node => 'host.domain.com.'))
    end

    it "should support trailing whitespace" do
      add_rule('allow host.domain.com    ')

      expect(@auth).to allow(request)
    end

    it "should support inlined comments" do
      add_rule('allow host.domain.com # will it work?')

      expect(@auth).to allow(request)
    end

    it "should deny non-matching host" do
      add_rule("allow inexistent")

      expect(@auth).not_to allow(request)
    end
  end

  describe "allow_ip" do
    it "should not warn when matches against IP addresses fail" do
      add_rule("allow_ip 10.1.1.2")

      expect(@auth).not_to allow(request)

      expect(@logs).not_to be_any {|log| log.level == :warning and log.message =~ /Authentication based on IP address is deprecated/}
    end

    it "should support IPv4 address" do
      add_rule("allow_ip 10.1.1.1")

      expect(@auth).to allow(request)
    end

    it "should support CIDR IPv4 address" do
      add_rule("allow_ip 10.0.0.0/8")

      expect(@auth).to allow(request)
    end

    it "should support wildcard IPv4 address" do
      add_rule("allow_ip 10.1.1.*")

      expect(@auth).to allow(request)
    end

    it "should support IPv6 address" do
      add_rule("allow_ip 2001:DB8::8:800:200C:417A")

      expect(@auth).to allow(request(:ip => '2001:DB8::8:800:200C:417A'))
    end

    it "should support hostname" do
      expect {
        add_rule("allow_ip host.domain.com")
      }.to raise_error Puppet::ConfigurationError, /Invalid IP pattern host.domain.com/
    end
  end

  describe "deny" do
    it "should deny denied hosts" do
      add_rule <<-EOALLOWRULE
        deny host.domain.com
        allow *.domain.com
      EOALLOWRULE

      expect(@auth).not_to allow(request)
    end

    it "denies denied hosts after allowing them" do
      add_rule <<-EOALLOWRULE
        allow *.domain.com
        deny host.domain.com
      EOALLOWRULE

      expect(@auth).not_to allow(request)
    end

    it "should not deny based on IP" do
      add_rule <<-EOALLOWRULE
        deny 10.1.1.1
        allow host.domain.com
      EOALLOWRULE

      expect(@auth).to allow(request)
    end

    it "should not deny based on IP (ordering #2)" do
      add_rule <<-EOALLOWRULE
        allow host.domain.com
        deny 10.1.1.1
      EOALLOWRULE

      expect(@auth).to allow(request)
    end
  end

  describe "deny_ip" do
    it "should deny based on IP" do
      add_rule <<-EOALLOWRULE
        deny_ip 10.1.1.1
        allow host.domain.com
      EOALLOWRULE

      expect(@auth).not_to allow(request)
    end

    it "should deny based on IP (ordering #2)" do
      add_rule <<-EOALLOWRULE
        allow host.domain.com
        deny_ip 10.1.1.1
      EOALLOWRULE

      expect(@auth).not_to allow(request)
    end
  end
end
