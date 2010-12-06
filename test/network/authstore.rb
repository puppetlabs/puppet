#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'mocha'
require 'puppet/network/authstore'

class TestAuthStore < Test::Unit::TestCase
  include PuppetTest
  Declaration = Puppet::Network::AuthStore::Declaration
  def mkstore
    store = nil
    assert_nothing_raised {
      store = Puppet::Network::AuthStore.new
    }

    store
  end

  def setup
    super
    @store = mkstore
  end

  def test_localallow
    Puppet[:trace] = false
    assert_nothing_raised {
      assert(@store.allowed?(nil, nil), "Store disallowed local access")
    }

    assert_raise(Puppet::DevError) {
      @store.allowed?("kirby.madstop.com", nil)
    }

    assert_raise(Puppet::DevError) {
      @store.allowed?(nil, "192.168.0.1")
    }
  end

  def test_simpleips
    %w{
      192.168.0.5
      7.0.48.7
    }.each { |ip|
      assert_nothing_raised("Failed to @store IP address #{ip}") {
        @store.allow(ip)
      }

      assert(@store.allowed?("hosttest.com", ip), "IP #{ip} not allowed")
    }

    #assert_raise(Puppet::AuthStoreError) {
    #    @store.allow("192.168.674.0")
    #}
  end

  def test_ipranges
    %w{
      192.168.0.*
      192.168.1.0/24
      192.178.*
      193.179.0.0/8
    }.each { |range|
      assert_nothing_raised("Failed to @store IP range #{range}") {
        @store.allow(range)
      }
    }

    %w{
      192.168.0.1
      192.168.1.5
      192.178.0.5
      193.0.0.1
    }.each { |ip|
      assert(@store.allowed?("fakename.com", ip), "IP #{ip} is not allowed")
    }
  end

  def test_iprangedenials
    assert_nothing_raised("Failed to @store overlapping IP ranges") {
      @store.allow("192.168.0.0/16")
      @store.deny("192.168.0.0/24")
    }

    assert(@store.allowed?("fake.name", "192.168.1.50"), "/16 ip not allowed")
    assert(! @store.allowed?("fake.name", "192.168.0.50"), "/24 ip allowed")
  end

  def test_subdomaindenails
    assert_nothing_raised("Failed to @store overlapping IP ranges") {
      @store.allow("*.madstop.com")
      @store.deny("*.sub.madstop.com")
    }


      assert(
        @store.allowed?("hostname.madstop.com", "192.168.1.50"),

      "hostname not allowed")

        assert(
          ! @store.allowed?("name.sub.madstop.com", "192.168.0.50"),

      "subname name allowed")
  end

  def test_orderingstuff
    assert_nothing_raised("Failed to @store overlapping IP ranges") {
      @store.allow("*.madstop.com")
      @store.deny("192.168.0.0/24")
    }


      assert(
        @store.allowed?("hostname.madstop.com", "192.168.1.50"),

      "hostname not allowed")

        assert(
          ! @store.allowed?("hostname.madstop.com", "192.168.0.50"),

      "Host allowed over IP")
  end

  def test_globalallow
    assert_nothing_raised("Failed to add global allow") {
      @store.allow("*")
    }

    [
      %w{hostname.com 192.168.0.4},
      %w{localhost 192.168.0.1},
      %w{localhost 127.0.0.1}

    ].each { |ary|
      assert(@store.allowed?(*ary), "Failed to allow #{ary.join(",")}")
    }
  end

  def test_store
    assert_nothing_raised do

      assert_nil(
        @store.send(:store, :allow, "*.host.com"),

        "store did not return nil")
    end
    assert_equal([Declaration.new(:allow, "*.host.com")],
      @store.send(:instance_variable_get, "@declarations"),
      "Did not store declaration")

    # Now add another one and make sure it gets sorted appropriately
    assert_nothing_raised do

      assert_nil(
        @store.send(:store, :allow, "me.host.com"),

        "store did not return nil")
    end


      assert_equal(
        [
          Declaration.new(:allow, "me.host.com"),

          Declaration.new(:allow, "*.host.com")
    ],
      @store.send(:instance_variable_get, "@declarations"),
      "Did not sort declarations")
  end

  def test_allow_and_deny
    store = Puppet::Network::AuthStore.new
    store.expects(:store).with(:allow, "host.com")
    store.allow("host.com")

    store = Puppet::Network::AuthStore.new
    store.expects(:store).with(:deny, "host.com")
    store.deny("host.com")

    store = Puppet::Network::AuthStore.new
    assert_nothing_raised do

      assert_nil(
        store.allow("*"),

        "allow did not return nil")
    end


      assert(
        store.globalallow?,

      "did not enable global allow")
  end

  def test_hostnames
    Puppet[:trace] = false
    %w{
      kirby.madstop.com
      luke.madstop.net
      name-other.madstop.net
    }.each { |name|
      assert_nothing_raised("Failed to @store simple name #{name}") {
        @store.allow(name)
      }
      assert(@store.allowed?(name, "192.168.0.1"), "Name #{name} not allowed")
    }

    %w{
      ^invalid!
      inval$id

    }.each { |pat|

      assert_raise(
        Puppet::AuthStoreError,

        "name '#{pat}' was allowed") {
        @store.allow(pat)
      }
    }
  end

  def test_domains
    assert_nothing_raised("Failed to @store domains") {
      @store.allow("*.a.very.long.domain.name.com")
      @store.allow("*.madstop.com")
      @store.allow("*.some-other.net")
      @store.allow("*.much.longer.more-other.net")
    }

    %w{
      madstop.com
      culain.madstop.com
      kirby.madstop.com
      funtest.some-other.net
      ya-test.madstop.com
      some.much.much.longer.more-other.net
    }.each { |name|
      assert(@store.allowed?(name, "192.168.0.1"), "Host #{name} not allowed")
    }

    assert_raise(Puppet::AuthStoreError) {
      @store.allow("domain.*.com")
    }


      assert(
        !@store.allowed?("very.long.domain.name.com", "1.2.3.4"),

      "Long hostname allowed")

    assert_raise(Puppet::AuthStoreError) {
      @store.allow("domain.*.other.com")
    }
  end

  # #531
  def test_case_insensitivity
    @store.allow("hostname.com")

    %w{hostname.com Hostname.COM hostname.Com HOSTNAME.COM}.each do |name|
      assert(@store.allowed?(name, "127.0.0.1"), "did not allow #{name}")
    end
  end

  def test_allowed?
    Puppet[:trace] = false

      assert(
        @store.allowed?(nil, nil),

      "Did not default to true for local checks")
    assert_raise(Puppet::DevError, "did not fail on one input") do
      @store.allowed?("host.com", nil)
    end
    assert_raise(Puppet::DevError, "did not fail on one input") do
      @store.allowed?(nil, "192.168.0.1")
    end

  end

  # Make sure more specific allows and denies win over generalities
  def test_specific_overrides
    @store.allow("host.madstop.com")
    @store.deny("*.madstop.com")


      assert(
        @store.allowed?("host.madstop.com", "192.168.0.1"),

      "More specific allowal by name failed")

    @store.allow("192.168.0.1")
    @store.deny("192.168.0.0/24")


      assert(
        @store.allowed?("host.madstop.com", "192.168.0.1"),

      "More specific allowal by ip failed")
  end

  def test_dynamic_backreferences
    @store.allow("$1.madstop.com")

    assert_nothing_raised { @store.interpolate([nil, "host"]) }
    assert(@store.allowed?("host.madstop.com", "192.168.0.1"), "interpolation failed")
    assert_nothing_raised { @store.reset_interpolation }
  end

  def test_dynamic_ip
    @store.allow("192.168.0.$1")

    assert_nothing_raised { @store.interpolate([nil, "12"]) }
    assert(@store.allowed?("host.madstop.com", "192.168.0.12"), "interpolation failed")
    assert_nothing_raised { @store.reset_interpolation }
  end

  def test_multiple_dynamic_backreferences
    @store.allow("$1.$2")

    assert_nothing_raised { @store.interpolate([nil, "host", "madstop.com"]) }
    assert(@store.allowed?("host.madstop.com", "192.168.0.1"), "interpolation failed")
    assert_nothing_raised { @store.reset_interpolation }
  end

  def test_multithreaded_allow_with_dynamic_backreferences
    @store.allow("$1.madstop.com")

    threads = []
    9.times { |a|
      threads << Thread.new {
        9.times { |b|
        Thread.pass
        @store.interpolate([nil, "a#{b}", "madstop.com"])
        Thread.pass
        assert( @store.allowed?("a#{b}.madstop.com", "192.168.0.1") )
        Thread.pass
        @store.reset_interpolation
        Thread.pass
      }
      }
    }
    threads.each { |th| th.join }
  end

end

class TestAuthStoreDeclaration < PuppetTest::TestCase
  include PuppetTest
  Declaration = Puppet::Network::AuthStore::Declaration

  def setup
    super
    @decl = Declaration.new(:allow, "hostname.com")
  end

  def test_parse
    {
      "192.168.0.1" =>        [:ip, IPAddr.new("192.168.0.1"), nil],
      "2001:700:300:1800::" => [:ip, IPAddr.new("2001:700:300:1800::"), nil],
      "2001:700:300:1800::/64" => [:ip, IPAddr.new("2001:700:300:1800::/64"), 64],
      "192.168.0.1/32" =>     [:ip, IPAddr.new("192.168.0.1/32"), 32],
      "192.168.0.1/24" =>     [:ip, IPAddr.new("192.168.0.1/24"), 24],
      "192.*" =>              [:ip, IPAddr.new("192.0.0.0/8"), 8],
      "192.168.*" =>          [:ip, IPAddr.new("192.168.0.0/16"), 16],
      "192.168.0.*" =>        [:ip, IPAddr.new("192.168.0.0/24"), 24],
      "hostname.com" =>       [:domain, %w{com hostname}, nil],
      "Hostname.COM" =>       [:domain, %w{com hostname}, nil],
      "billy.Hostname.COM" => [:domain, %w{com hostname billy}, nil],
      "billy-jean.Hostname.COM" => [:domain, %w{com hostname billy-jean}, nil],
      "*.hostname.COM" => [:domain, %w{com hostname}, 2],
      "*.hostname.COM" => [:domain, %w{com hostname}, 2],
      "$1.hostname.COM" => [:dynamic, %w{com hostname $1}, nil],
      "192.168.$1.$2" => [:dynamic, %w{$2 $1 168 192}, nil],
      "8A5BC90C-B8FD-4CBC-81DA-BAD84D551791" => [:opaque, %w{8A5BC90C-B8FD-4CBC-81DA-BAD84D551791}, nil]
    }.each do |input, output|

      # Create a new decl each time, so values aren't cached.
      assert_nothing_raised do
        @decl = Declaration.new(:allow, input)
      end

      [:name, :pattern, :length].zip(output).each do |method, value|
        assert_equal(value, @decl.send(method), "Got incorrect value for #{method} from #{input}")
      end
    end

    %w{-hostname.com hostname.*}.each do |input|
      assert_raise(Puppet::AuthStoreError, "Did not fail on #{input}") do
        @decl.pattern = input
      end
    end

    ["hostname .com", "192.168 .0.1"].each do |input|
      assert_raise(Puppet::AuthStoreError, "Did not fail on #{input}") do
        @decl.pattern = input
      end
    end
  end

  def test_result
    ["allow", :allow].each do |val|
      assert_nothing_raised { @decl.type = val }
      assert_equal(true, @decl.result, "did not result to true with #{val.inspect}")
    end

    [:deny, "deny"].each do |val|
      assert_nothing_raised { @decl.type = val }

        assert_equal(
          false, @decl.result,

          "did not result to false with #{val.inspect}")
    end

    ["yay", 1, nil, false, true].each do |val|
      assert_raise(ArgumentError, "Did not fail on #{val.inspect}") do
        @decl.type = val
      end
    end
  end

  def test_munge_name
    {
      "hostname.com" => %w{com hostname},
      "alley.hostname.com" => %w{com hostname alley},
      "*.hostname.com" => %w{com hostname *},
      "*.HOSTNAME.Com" => %w{com hostname *},
      "*.HOSTNAME.Com" => %w{com hostname *},

    }.each do |input, output|
      assert_equal(output, @decl.send(:munge_name, input), "munged #{input} incorrectly")
    end
  end

  # Make sure people can specify TLDs
  def test_match_tlds
    assert_nothing_raised {
      @decl.pattern = "*.tld"
    }

    assert_equal(%w{tld}, @decl.pattern, "Failed to allow custom tld")
  end

  # Make sure we sort correctly.
  def test_sorting
    # Make sure declarations with no length sort first.
    host_exact = Declaration.new(:allow, "host.com")
    host_range = Declaration.new(:allow, "*.host.com")

    ip_exact = Declaration.new(:allow, "192.168.0.1")
    ip_range = Declaration.new(:allow, "192.168.0.*")


      assert_equal(
        -1, host_exact <=> host_range,

      "exact name match did not sort first")


        assert_equal(
          -1, ip_exact <=> ip_range,

      "exact ip match did not sort first")

    # Next make sure we sort by length
    ip_long = Declaration.new(:allow, "192.168.*")
    assert_equal(-1, ip_range <=> ip_long, "/16 sorted before /24 in ip")

    # Now try it using masks
    ip24 = Declaration.new(:allow, "192.168.0.0/24")
    ip16 = Declaration.new(:allow, "192.168.0.0/16")

    assert_equal(-1, ip24 <=> ip16, "/16 sorted before /24 in ip with masks")

    # Make sure ip checks sort before host checks
    assert_equal(-1, ip_exact <=> host_exact, "IP exact did not sort before host exact")


      assert_equal(
        -1, ip_range <=> host_range,

      "IP range did not sort before host range")

    host_long = Declaration.new(:allow, "*.domain.host.com")

    assert_equal(-1, host_long <=> host_range, "did not sort by domain length")

    # Now make sure denies sort before allows, for equivalent
    # declarations.
    host_deny = Declaration.new(:deny, "host.com")
    assert_equal(-1, host_deny <=> host_exact, "deny did not sort before allow when exact")

    host_range_deny = Declaration.new(:deny, "*.host.com")
    assert_equal(-1, host_range_deny <=> host_range, "deny did not sort before allow when ranged")

    ip_allow = Declaration.new(:allow, "192.168.0.0/16")
    ip_deny = Declaration.new(:deny, "192.168.0.0/16")


      assert_equal(
        -1, ip_deny <=> ip_allow,

      "deny did not sort before allow in ip range")

    %w{host.com *.domain.com 192.168.0.1 192.168.0.1/24}.each do |decl|
      assert_equal(0, Declaration.new(:allow, decl) <=>
        Declaration.new(:allow, decl),
        "Equivalent declarations for #{decl} were considered different"
      )
    end
  end

  def test_match?
    host = Declaration.new(:allow, "host.com")
    host.expects(:matchname?).with("host.com")
    host.match?("host.com", "192.168.0.1")

    ip = Declaration.new(:allow, "192.168.0.1")
    ip.pattern.expects(:include?)
    ip.match?("host.com", "192.168.0.1")
  end

  def test_matchname?
    host = Declaration.new(:allow, "host.com")
    assert(host.send(:matchname?, "host.com"), "exact did not match")
    assert(! host.send(:matchname?, "yay.com"), "incorrect match")

    domain = Declaration.new(:allow, "*.domain.com")
    %w{host.domain.com domain.com very.long.domain.com very-long.domain.com }.each do |name|
      assert(domain.send(:matchname?, name), "Did not match #{name}")
    end
  end
end


