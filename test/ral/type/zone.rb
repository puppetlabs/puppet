#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/type/zone'

class TestZone < PuppetTest::TestCase
  confine "Zones are only functional on Solaris" => (Facter["operatingsystem"].value == "Solaris")

  def setup
    super
    @@zones = []
  end

  def mkzone(name)
    zone = nil

    base = tempfile
    Dir.mkdir(base)
    File.chmod(0700, base)
    root = File.join(base, "zonebase")
    assert_nothing_raised {

      zone = Puppet::Type.type(:zone).new(

        :name => name,
        :path => root,

        :ensure => "configured" # don't want to install zones automatically
      )
    }

    @@zones << name

    zone
  end

  def test_instances
    list = nil
    assert_nothing_raised {
      list = Puppet::Type.type(:zone).instances
    }

    assert(! list.empty?, "Got no zones back")

    assert(list.find { |z| z[:name] == "global" }, "Could not find global zone")
  end

  def test_state_sequence
    zone = mkzone("slicetest")

    property = zone.property(:ensure)

    slice = nil
    assert_nothing_raised {
      slice = property.class.state_sequence(:absent, :installed).collect do |o|
        o[:name]
      end
    }


    assert_equal([:configured, :installed], slice)

    assert_nothing_raised {
      slice = property.class.state_sequence(:running, :installed).collect do |o|
        o[:name]
      end
    }


    assert_equal(slice, [:installed])

  end

  # Make sure the ensure stuff behaves as we expect
  def test_zoneensure
    zone = mkzone("ensurezone")

    property = zone.property(:ensure)

    assert(property, "Did not get ensure property")

    values = nil
    assert_nothing_raised {
      values = zone.retrieve
    }

    assert(! property.insync?(values[property]), "Property is somehow in sync")

    assert(property.up?, "Property incorrectly thinks it is not moving up")

    zone[:ensure] = :installed
    assert(property.up?, "Property incorrectly thinks it is not moving up")
    zone[:ensure] = :absent
    assert(! property.up?, "Property incorrectly thinks it is moving up")
  end

  # Make sure all mentioned methods actually exist.
  def test_zonemethods_exist
    methods = []
    zone = mkzone("methodtest")

    property = zone.property(:ensure)
    assert_nothing_raised {
      property.class.state_sequence(:absent, :running).each do |st|
        [:up, :down].each do |m|
          methods << st[m] if st[m]
        end
      end
    }

    methods.each do |m|
      Puppet::Type.type(:zone).suitableprovider.each do |prov|

        assert(
          prov.method_defined?(m),

          "Zone provider #{prov.name} does not define method #{m}")
      end
    end

  end

  # Make sure our property generates the correct text.
  def test_inherit_property
    zone = mkzone("configtesting")
    zone[:ensure] = :configured

    assert_nothing_raised {
      zone[:inherit] = "/usr"
    }
    property = zone.property(:inherit)
    assert(zone, "Did not get 'inherit' property")


      assert_equal(
        "add inherit-pkg-dir\nset dir=/usr\nend", property.configtext,

      "Got incorrect config text")

    zone.provider.inherit = "/usr"


      assert_equal(
        "", property.configtext,

      "Got incorrect config text")

    # Now we want multiple directories
    property.should = %w{/usr /sbin /lib}

    # The statements are sorted
    text = "add inherit-pkg-dir
set dir=/lib
end
add inherit-pkg-dir
set dir=/sbin
end"


  assert_equal(
    text, property.configtext,

      "Got incorrect config text")

    zone.provider.inherit = %w{/usr /sbin /lib}
    property.should = %w{/usr /sbin}

    text = "remove inherit-pkg-dir dir=/lib"


      assert_equal(
        text, property.configtext,

      "Got incorrect config text")
  end
end

class TestZoneAsRoot < TestZone
  confine "Not running Zone creation tests" => Puppet.features.root?
  confine "Zones are only functional on Solaris" => (Facter["operatingsystem"].value == "Solaris")

  def teardown
    current = %x{zoneadm list -cp}.split("\n").inject({}) { |h, line|
      ary = line.split(":")
      h[ary[1]] = ary[2]
      h
    }

    # Get rid of any lingering zones
    @@zones.each do |zone|
      next unless current.include? zone

      obj = Puppet::Type.type(:zone).new(:name => zone)
      obj[:ensure] = :absent
      assert_apply(obj)
    end

    # We can't delete the temp files until the zones are stopped and removed.
    super
  end
  # Make sure our ensure process actually works.
  def test_ensure_sync
    zone = mkzone("ensuretesting")

    zone[:ensure] = :configured

    assert_apply(zone)

    assert(zone.insync?(zone.retrieve), "Zone is not insync")
  end

  def test_getconfig
    zone = mkzone("configtesting")

    base = tempfile
    zone[:path] = base

    ip = "192.168.0.1"
    interface = "bge0"
    zone[:ip] = "#{interface}:#{ip}"

    IO.popen("zonecfg -z configtesting -f -", "w") do |f|
      f.puts %{create -b
set zonepath=#{tempfile}
set autoboot=true
add inherit-pkg-dir
set dir=/lib
end
add inherit-pkg-dir
set dir=/platform
end
add inherit-pkg-dir
set dir=/sbin
end
add inherit-pkg-dir
set dir=/opt/csw
end
add inherit-pkg-dir
set dir=/usr
end
add net
set address=#{ip}
set physical=bge0
end
}
  end

  assert_equal(0, $CHILD_STATUS, "Did not successfully create zone")

  hash = nil
  assert_nothing_raised {
    hash = zone.provider.send(:getconfig)
    }

    zone[:check] = [:inherit, :autoboot]

    values = nil
    assert_nothing_raised("Could not retrieve zone values") do
      values = zone.retrieve.inject({}) { |result, newvals| result[newvals[0].name] = newvals[1]; result }
    end

    # And make sure it gets set correctly.

      assert_equal(
        %w{/sbin /usr /opt/csw /lib /platform}.sort,

      values[:inherit].sort, "Inherited dirs did not get collected correctly."
    )


      assert_equal(
        ["#{interface}:#{ip}"], values[:ip],

      "IP addresses did not get collected correctly.")


        assert_equal(
          :true, values[:autoboot],

      "Autoboot did not get collected correctly.")
  end

  # Make sure we can do all the various and sundry configuring things.
  def test_configuring_zones
    zone = mkzone("configtesting")

    assert_nothing_raised {
      zone[:inherit] = "/usr"
    }

    zone[:ensure] = :configured

    assert_apply(zone)

    assert(zone.insync?(zone.retrieve), "Zone is not insync")

    # Now add a new directory to inherit
    assert_nothing_raised {
      zone[:inherit] = ["/sbin", "/usr"]
    }
    assert_apply(zone)

    assert(zone.insync?(zone.retrieve), "Zone is not insync")


      assert(
        %x{/usr/sbin/zonecfg -z #{zone[:name]} info} =~ /dir: \/sbin/,

      "sbin was not added")

    # And then remove it.
    assert_nothing_raised {
      zone[:inherit] = "/usr"
    }
    assert_apply(zone)

    assert(zone.insync?(zone.retrieve), "Zone is not insync")


      assert(
        %x{/usr/sbin/zonecfg -z #{zone[:name]} info} !~ /dir: \/sbin/,

      "sbin was not removed")

    # Now add an ip adddress.  Fortunately (or not), zonecfg doesn't verify
    # that the interface exists.
    zone[:ip] = "hme0:192.168.0.1"

    assert(! zone.insync?(zone.retrieve), "Zone is marked as in sync")

    assert_apply(zone)
    assert(zone.insync?(zone.retrieve), "Zone is not in sync")

      assert(
        %x{/usr/sbin/zonecfg -z #{zone[:name]} info} =~ /192.168.0.1/,

      "ip was not added")
    zone[:ip] = ["hme1:192.168.0.2", "hme0:192.168.0.1"]
    assert_apply(zone)
    assert(zone.insync?(zone.retrieve), "Zone is not in sync")
    assert(%x{/usr/sbin/zonecfg -z #{zone[:name]} info} =~ /192.168.0.2/, "ip was not added")
    zone[:ip] = ["hme1:192.168.0.2"]
    assert_apply(zone)
    zone.retrieve
    assert(%x{/usr/sbin/zonecfg -z #{zone[:name]} info} !~ /192.168.0.1/, "ip was not removed")
  end

  # Test creating and removing a zone, but only up to the configured property,
  # so it's faster.
  def test_smallcreate
    zone = mkzone("smallcreate")
    # Include a bunch of stuff so the zone isn't as large
    dirs = %w{/usr /sbin /lib /platform}

    %w{/opt/csw}.each do |dir|
      dirs << dir if FileTest.exists? dir
    end
    zone[:inherit] = dirs

    assert(zone, "Did not make zone")

    zone[:ensure] = :configured

    assert(! zone.insync?(zone.retrieve), "Zone is incorrectly in sync")

    assert_apply(zone)

    assert(zone.insync?(zone.retrieve), "Zone is incorrectly out of sync")

    zone[:ensure] = :absent

    assert_apply(zone)

    currentvalues = zone.retrieve

    assert_equal(:absent, currentvalues[zone.property(:ensure)],
      "Zone is not absent")
  end

  # Just go through each method linearly and make sure it works.
  def test_each_method
    zone = mkzone("methodtesting")
    dirs = %w{/usr /sbin /lib /platform}

    %w{/opt/csw}.each do |dir|
      dirs << dir if FileTest.exists? dir
    end
    zone[:inherit] = dirs

    [[:configure, :configured],
      [:install, :installed],
      [:start, :running],
      [:stop, :installed],
      [:uninstall, :configured],
      [:unconfigure, :absent]
    ].each do |method, property|
      Puppet.info "Testing #{method}"
      current_values = nil
      assert_nothing_raised {
        current_values = zone.retrieve
      }
      assert_nothing_raised {
        zone.provider.send(method)
      }
      current_values = nil
      assert_nothing_raised {
        current_values = zone.retrieve
      }
      assert_equal(property, current_values[zone.property(:ensure)], "Method #{method} did not correctly set property #{property}")
    end
  end

  def test_mkzone
    zone = mkzone("testmaking")
    # Include a bunch of stuff so the zone isn't as large
    dirs = %w{/usr /sbin /lib /platform}

    %w{/opt/csw}.each do |dir|
      dirs << dir if FileTest.exists? dir
    end
    zone[:inherit] = dirs

    assert(zone, "Did not make zone")


    [:configured, :installed, :running, :installed, :absent].each do |value|
      assert_nothing_raised {
        zone[:ensure] = value
      }
      assert(! zone.insync?(zone.retrieve), "Zone is incorrectly in sync")

      assert_apply(zone)

      assert_nothing_raised {
        assert(zone.insync?(zone.retrieve), "Zone is incorrectly out of sync")
      }
    end

    currentvalues = zone.retrieve

    assert_equal(:absent, currentvalues[zone.property(:ensure)],
      "Zone is not absent")
  end
end

