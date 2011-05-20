#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'puppet/network/authorization'
require 'mocha'

class TestAuthConfig < Test::Unit::TestCase
  include PuppetTest

  # A mock class for authconfig
  class FakeAuth
    class << self
      attr_accessor :allow, :exists
    end
    def allowed?(req)
      self.class.allow
    end
    def exists?
      self.class.exists
    end
  end

  class AuthTest
    include Puppet::Network::Authorization

    def clear
      @loaded.clear
    end

    def load(name)
      @loaded ||= []
      @loaded << name
    end

    def handler_loaded?(name)
      @loaded ||= []
      @loaded.include?(name)
    end
  end

  def setup
    super
    @obj = AuthTest.new

    # Override the authconfig to make life easier
    class << @obj
      def authconfig
        @authconfig ||= FakeAuth.new
      end
    end
    @request = Puppet::Network::ClientRequest.new("host", "ip", false)
    @request.handler = "foo"
    @request.method = "bar"
  end

  def test_authconfig
    obj = AuthTest.new
    auth = nil
    assert_nothing_raised { auth = obj.send(:authconfig) }
    assert(auth, "did not get auth")
    assert_equal(Puppet::Network::AuthConfig.main.object_id, auth.object_id, "did not get main authconfig")
  end

  def test_authorize
    # Make sure that unauthenticated clients can do puppetca stuff, but
    # nothing else.
    @request.handler = "puppetca"
    @request.method = "yay"
    assert(@obj.authorized?(@request), "Did not allow unauthenticated ca call")
    assert_logged(:notice, /Allowing/, "did not log call")
    @request.handler = "other"
    assert(! @obj.authorized?(@request), "Allowed unauthencated other call")
    assert_logged(:notice, /Denying/, "did not log call")

    @request.authenticated = true
    # We start without the namespace auth file, so everything should
    # start out denied
    assert(! @obj.authorized?(@request), "Allowed call with no config file")
    assert_logged(:notice, /Denying/, "did not log call")

    # Now set our run_mode to master, so calls are allowed
    Puppet.run_mode.stubs(:master?).returns true

          assert(
        @obj.authorized?(@request),
        
      "Denied call with no config file and master")
    assert_logged(:debug, /Allowing/, "did not log call")

    # Now "create" the file, so we do real tests
    FakeAuth.exists = true

    # We start out denying
    assert(! @obj.authorized?(@request), "Allowed call when denying")
    assert_logged(:notice, /Denying/, "did not log call")

    FakeAuth.allow = true
    assert(@obj.authorized?(@request), "Denied call when allowing")
    assert_logged(:debug, /Allowing/, "did not log call")
  end

  def test_available?
    # Start out false
    assert(! @obj.available?(@request), "Defaulted to true")
    assert_logged(:warning, /requested unavailable/, "did not log call")

    @obj.load(@request.handler)
    assert(@obj.available?(@request), "did not see it loaded")
  end

  # Make sure we raise things appropriately
  def test_verify
    # Start out unavailabl
    assert_raise(Puppet::Network::InvalidClientRequest) do
      @obj.verify(@request)
    end
    class << @obj
      def available?(req)
        true
      end
    end
    assert_raise(Puppet::Network::InvalidClientRequest) do
      @obj.verify(@request)
    end
    class << @obj
      def authorized?(req)
        true
      end
    end
    assert_nothing_raised do
      @obj.verify(@request)
    end
  end
end


