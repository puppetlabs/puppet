#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/puppettest')

require 'mocha'

class UserAddProviderTest < PuppetTest::TestCase
  confine "useradd user provider missing" =>
    Puppet::Type.type(:user).provider(:useradd).suitable?

  def setup
    super
    @type = Puppet::Type.type(:user)
    @provider = Puppet::Type.type(:user).provider(:useradd)
    @home = tempfile
    @vals = {:name => 'faff',
      :provider => :useradd,
      :ensure => :present,
      :uid => 5000,
      :gid => 5000,
      :home => @home,
      :comment => "yayness",
      :groups => %w{one two}
    }
  end

  def setup_user
    @user = @type.new(@vals)

    @vals.each do |name, val|
      next unless @user.class.validproperty?(name)
    end
    @user
  end

  def test_features
    [:manages_homedir].each do |feature|

            assert(
        @provider.feature?(feature),
        
        "useradd provider is missing #{feature}")
    end
  end

  def test_create
    user = setup_user

    @vals.each do |name, val|
      next unless user.class.validproperty?(name)
    end

    user.expects(:allowdupe?).returns(false)
    user.expects(:managehome?).returns(false)

    user.provider.expects(:execute).with do |params|
      command = params.shift
      assert_equal(@provider.command(:add), command,
        "Got incorrect command")

      if %w{Fedora RedHat}.include?(Facter.value(:operatingsystem))
        assert(params.include?("-M"), "Did not disable homedir creation on red hat")
        params.delete("-M")
      end

      options = {}
      options[params.shift] = params.shift while params.length > 0

      @vals[:groups] = @vals[:groups].join(",")

      flags = {:home => "-d", :groups => "-G", :gid => "-g",
        :uid => "-u", :comment => "-c"}

      flags.each do |param, flag|
        assert_equal(@vals[param], options[flag], "Got incorrect value for #{param}")
      end

      true
    end

    user.provider.create
  end

  # Make sure we add the right flags when managing home
  def test_managehome
    @vals[:managehome] = true
    setup_user


          assert(
        @user.provider.respond_to?(:manages_homedir?),
        
      "provider did not get managehome test set")

    assert(@user.managehome?, "provider did not get managehome")

    # First run
    @user.expects(:managehome?).returns(true)

    @user.provider.expects(:execute).with do |params|
      assert_equal(params[0], @provider.command(:add), "useradd was not called")
      assert(params.include?("-m"), "Did not add -m when managehome was in affect")
      assert(! params.include?("-M"), "Added -M when managehome was in affect")

      true
    end

    @user.provider.create

    # Start again, this time with manages_home off
    @vals[:managehome] = false
    setup_user

    # First run
    @user.expects(:managehome?).returns(false)

    @user.provider.expects(:execute).with do |params|
      assert_equal(params[0], @provider.command(:add), "useradd was not called")
      assert(params.include?("-M"), "Did not add -M on Red Hat") if %w{Fedora RedHat}.include?(Facter.value(:operatingsystem))
      assert(! params.include?("-m"), "Added -m when managehome was disabled")

      true
    end

    @user.provider.create
  end

  def test_allowdupe
    @vals[:allowdupe] = true
    setup_user


          assert(
        @user.provider.respond_to?(:allows_duplicates?),
        
      "provider did not get allowdupe test set")

    assert(@user.allowdupe?, "provider did not get allowdupe")

    # First run
    @user.expects(:allowdupe?).returns(true)

    @user.provider.expects(:execute).with do |params|
      assert_equal(params[0], @provider.command(:add), "useradd was not called")
      assert(params.include?("-o"), "Did not add -o when allowdupe was in affect")

      true
    end

    @user.provider.create

    # Start again, this time with manages_home off
    @vals[:allowdupe] = false
    setup_user

    # First run
    @user.expects(:allowdupe?).returns(false)

    @user.provider.expects(:execute).with do |params|
      assert_equal(params[0], @provider.command(:add), "useradd was not called")
      assert(! params.include?("-o"), "Added -o when allowdupe was disabled")

      true
    end

    @user.provider.create
  end

  def test_manages_password
    return unless @provider.feature?(:manages_passwords)
    @vals[:password] = "somethingorother"
    setup_user

    @user.provider.expects(:execute).with do |params|
      assert_equal(params[0], @provider.command(:add), "useradd was not called")
      params.shift
      options = {}
      params.each_with_index do |p, i|
        if p =~ /^-/ and p != "-M"
          options[p] = params[i + 1]
        end
      end
      assert_equal(options["-p"], @vals[:password], "Did not set password in useradd call")
      true
    end

    @user.provider.create

    # Now mark the user made, and make sure the right command is called
    setup_user
    @vals[:password] = "somethingelse"

    @user.provider.expects(:execute).with do |params|
      assert_equal(params[0], @provider.command(:modify), "usermod was not called")

      options = {}
      params.each_with_index do |p, i|
        if p =~ /^-/ and p != "-M"
          options[p] = params[i + 1]
        end
      end

            assert_equal(
        options["-p"], @vals[:password],
        
        "Did not set password in useradd call")
      true
    end

    @user.provider.password = @vals[:password]
  end

end

class UserRootAddProviderTest < PuppetTest::TestCase
  confine "useradd user provider missing" => Puppet::Type.type(:user).provider(:useradd).suitable?
  confine "useradd does not manage passwords" => Puppet::Type.type(:user).provider(:useradd).manages_passwords?
  confine "not running as root" => (Process.uid == 0)

  def test_password
    user = Puppet::Type.type(:user).new(:name => "root", :check => [:password], :provider => :useradd)

    provider = user.provider

    assert_nothing_raised("Could not check password") do
      pass = provider.password
      assert(pass, "Did not get password for root")
      assert(pass!= "x", "Password was retrieved from /etc/passwd instead of /etc/shadow")
    end
  end
end


