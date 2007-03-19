#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../lib/puppettest'

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
		@user = @type.create(@vals)

        @vals.each do |name, val|
            next unless @user.class.validproperty?(name)
            @user.is = [name, :absent]
        end
        @user
    end

    def test_features
        [:manages_homedir].each do |feature|
            assert(@provider.feature?(feature),
                "useradd provider is missing %s" % feature)
        end
    end
	
	def test_create
		user = setup_user

        @vals.each do |name, val|
            next unless user.class.validproperty?(name)
            user.is = [name, :absent]
        end

        user.expects(:allowdupe?).returns(false)
        user.expects(:managehome?).returns(false)

		user.provider.expects(:execute).with do |params|
            command = params.shift
            assert_equal(@provider.command(:add), command,
                "Got incorrect command")

            if %w{Fedora RedHat}.include?(Facter.value(:operatingsystem))
                assert(params.include?("-M"),
                    "Did not disable homedir creation on red hat")
                params.delete("-M")
            end

            options = {}
            while params.length > 0
                options[params.shift] = params.shift
            end

            @vals[:groups] = @vals[:groups].join(",")

            flags = {:home => "-d", :groups => "-G", :gid => "-g",
                :uid => "-u", :comment => "-c"}

            flags.each do |param, flag|
                assert_equal(@vals[param], options[flag],
                    "Got incorrect value for %s" % param)
            end

            true
        end
		
        user.provider.create
	end

    # Make sure we add the right flags when managing home
    def test_managehome
        @vals[:managehome] = true
        setup_user

        assert(@user.provider.respond_to?(:manages_homedir?),
            "provider did not get managehome test set")

        assert(@user.managehome?, "provider did not get managehome")

        # First run
        @user.expects(:managehome?).returns(true)

		@user.provider.expects(:execute).with do |params|
            assert_equal(params[0], @provider.command(:add),
                "useradd was not called")
            assert(params.include?("-m"),
                "Did not add -m when managehome was in affect")

            true
        end

        @user.provider.create
        @user.class.clear

        # Start again, this time with manages_home off
        @vals[:managehome] = false
        setup_user

        # First run
        @user.expects(:managehome?).returns(false)

		@user.provider.expects(:execute).with do |params|
            assert_equal(params[0], @provider.command(:add),
                "useradd was not called")
            if %w{Fedora RedHat}.include?(Facter.value(:operatingsystem))
                assert(params.include?("-M"),
                    "Did not add -M on Red Hat")
            end
                assert(! params.include?("-m"),
                    "Added -m when managehome was disabled")

            true
        end

        @user.provider.create
    end

    def test_allowdupe
        @vals[:allowdupe] = true
        setup_user

        assert(@user.provider.respond_to?(:allows_duplicates?),
            "provider did not get allowdupe test set")

        assert(@user.allowdupe?, "provider did not get allowdupe")

        # First run
        @user.expects(:allowdupe?).returns(true)

		@user.provider.expects(:execute).with do |params|
            assert_equal(params[0], @provider.command(:add),
                "useradd was not called")
            assert(params.include?("-o"),
                "Did not add -o when allowdupe was in affect")

            true
        end

        @user.provider.create
        @user.class.clear

        # Start again, this time with manages_home off
        @vals[:allowdupe] = false
        setup_user

        # First run
        @user.expects(:allowdupe?).returns(false)

		@user.provider.expects(:execute).with do |params|
            assert_equal(params[0], @provider.command(:add),
                "useradd was not called")
            assert(! params.include?("-o"),
                "Added -o when allowdupe was disabled")

            true
        end

        @user.provider.create
    end

    def disabled_test_manages_password
        if Facter.value(:kernel) != "Linux"
            assert(! @provider.feature?(:manages_passwords),
                "Defaulted to managing passwords on %s" %
                Facter.value(:kernel))

            # Now just make sure it's not allowed, and return
            setup_user
            assert_raise(Puppet::Error, "allowed passwd mgmt on failing host") do
                @user[:password] = "yayness"
            end
            return
        end

        # Now, test that it works correctly.
        assert(@provider.manages_passwords?,
            "Defaulted to not managing passwords on %s" %
            Facter.value(:kernel))
        @vals[:password] = "somethingorother"
        setup_user

		@user.provider.expects(:execute).with do |params|
            assert_equal(params[0], @provider.command(:add),
                "useradd was not called")
            params.shift
            options = {}
            params.each_with_index do |p, i|
                if p =~ /^-/ and p != "-M"
                    options[p] = params[i + 1]
                end
            end
            assert_equal(options["-p"], @vals[:password],
                "Did not set password in useradd call")
            true
        end

        @user.provider.create
        @user.class.clear

        # Now mark the user made, and make sure the right command is called
        setup_user
        @user.is = [:ensure, :present]
        @user.is = [:password, :present]
        @vals[:password] = "somethingelse"

		@user.provider.expects(:execute).with do |params|
            assert_equal(params[0], @provider.command(:modify),
                "usermod was not called")

            options = {}
            params.each_with_index do |p, i|
                if p =~ /^-/ and p != "-M"
                    options[p] = params[i + 1]
                end
            end
            assert_equal(options["-p"], @vals[:password],
                "Did not set password in useradd call")
            true
        end

        @user.provider.password = @vals[:password]
    end
end

# $Id$
