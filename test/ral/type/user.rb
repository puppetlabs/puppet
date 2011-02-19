#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'etc'

class TestUser < Test::Unit::TestCase
  include PuppetTest

  p = Puppet::Type.type(:user).provide :fake, :parent => PuppetTest::FakeProvider do
    @name = :fake
    apimethods
    def create
      @ensure = :present
      @resource.send(:properties).each do |property|
        next if property.name == :ensure
        property.sync
      end
    end

    def delete
      @ensure = :absent
      @resource.send(:properties).each do |property|
        send(property.name.to_s + "=", :absent)
      end
    end

    def exists?
      if @ensure == :present
        true
      else
        false
      end
    end
  end

  FakeUserProvider = p

  @@fakeproviders[:group] = p

  def findshell(old = nil)
    %w{/bin/sh /bin/bash /sbin/sh /bin/ksh /bin/zsh /bin/csh /bin/tcsh
      /usr/bin/sh /usr/bin/bash /usr/bin/ksh /usr/bin/zsh /usr/bin/csh
      /usr/bin/tcsh}.find { |shell|
        if old
          FileTest.exists?(shell) and shell != old
        else
          FileTest.exists?(shell)
        end
    }
  end

  def setup
    super
    Puppet::Type.type(:user).defaultprovider = FakeUserProvider
  end

  def teardown
    Puppet::Type.type(:user).defaultprovider = nil
    super
  end

  def mkuser(name)
    user = nil
    assert_nothing_raised {

            user = Puppet::Type.type(:user).new(
                
        :name => name,
        :comment => "Puppet Testing User",
        :gid => Puppet::Util::SUIDManager.gid,
        :shell => findshell,
        
        :home => "/home/#{name}"
      )
    }

    assert(user, "Did not create user")

    user
  end

  def test_autorequire
    file = tempfile
    comp = nil
    user = nil
    group =nil
    home = nil
    ogroup = nil
    assert_nothing_raised {

            user = Puppet::Type.type(:user).new(
                
        :name => "pptestu",
        :home => file,
        :gid => "pptestg",
        
        :groups => "yayness"
      )

            home = Puppet::Type.type(:file).new(
                
        :path => file,
        :owner => "pptestu",
        
        :ensure => "directory"
      )
      group = Puppet::Type.type(:group).new(
        :name => "pptestg"
      )
      ogroup = Puppet::Type.type(:group).new(
        :name => "yayness"
      )
      comp = mk_catalog(user, group, home, ogroup)
    }

    rels = nil
    assert_nothing_raised { rels = user.autorequire }

    assert(rels.detect { |r| r.source == group }, "User did not require group")
    assert(rels.detect { |r| r.source == ogroup }, "User did not require other groups")
    assert_nothing_raised { rels = home.autorequire }
    assert(rels.detect { |r| r.source == user }, "Homedir did not require user")
  end

  # Testing #455
  def test_autorequire_with_no_group_should
    user = Puppet::Type.type(:user).new(:name => "yaytest", :check => :all)
    catalog = mk_catalog(user)

    assert_nothing_raised do
      user.autorequire
    end

    user[:ensure] = :absent

    assert(user.property(:groups).insync?(nil),
      "Groups state considered out of sync with no :should value")
  end

  # Make sure the 'managehome' param can only be set when the provider
  # has that feature.  Uses a patch from #432.
  def test_managehome
    user = Puppet::Type.type(:user).new(:name => "yaytest", :check => :all)

    prov = user.provider

    home = false
    prov.class.meta_def(:manages_homedir?) { home }

    assert_nothing_raised("failed on false managehome") do
      user[:managehome] = false
    end

    assert_raise(Puppet::Error, "did not fail when managehome? is false") do
      user[:managehome] = true
    end

    home = true
    assert(prov.class.manages_homedir?, "provider did not enable homedir")
    assert_nothing_raised("failed when managehome is true") do
      user[:managehome] = true
    end
  end
end

