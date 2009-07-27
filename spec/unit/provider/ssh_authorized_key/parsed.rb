#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppettest'
require 'puppettest/support/utils'
require 'puppettest/fileparsing'

provider_class = Puppet::Type.type(:ssh_authorized_key).provider(:parsed)

describe provider_class do
    include PuppetTest
    include PuppetTest::FileParsing

    before :each do
        @sshauthkey_class = Puppet::Type.type(:ssh_authorized_key)
        @provider = @sshauthkey_class.provider(:parsed)
    end

    after :each do
        @provider.initvars
    end

    def mkkey(args)
        fakeresource = fakeresource(:ssh_authorized_key, args[:name])

        key = @provider.new(fakeresource)
        args.each do |p,v|
            key.send(p.to_s + "=", v)
        end

        return key
    end

    def genkey(key)
        @provider.filetype = :ram
        file = @provider.default_target

        key.flush
        text = @provider.target_object(file).read
        return text
    end

    it "should be able to parse each example" do
        fakedata("data/providers/ssh_authorized_key/parsed").each { |file|
            puts "Parsing %s" % file
            fakedataparse(file)
        }
    end

    it "should be able to generate a basic authorized_keys file" do
        key = mkkey({
            :name => "Just Testing",
            :key => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
            :type => "ssh-dss",
            :ensure => :present,
            :options => [:absent]
        })

        genkey(key).should == "ssh-dss AAAAfsfddsjldjgksdflgkjsfdlgkj Just Testing\n"
    end

    it "should be able to generate a authorized_keys file with options" do
        key = mkkey({
            :name => "root@localhost",
            :key => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
            :type => "ssh-rsa",
            :ensure => :present,
            :options => ['from="192.168.1.1"', "no-pty", "no-X11-forwarding"]
        })

        genkey(key).should == "from=\"192.168.1.1\",no-pty,no-X11-forwarding ssh-rsa AAAAfsfddsjldjgksdflgkjsfdlgkj root@localhost\n"
    end

    it "'s parse_options method should be able to parse options containing commas" do
        options = %w{from="host1.reductlivelabs.com,host.reductivelabs.com" command="/usr/local/bin/run" ssh-pty}
        optionstr = options.join(", ")

        @provider.parse_options(optionstr).should == options
    end
end

describe provider_class do
    before :each do
        @resource = stub("resource", :name => "foo")
        @resource.stubs(:[]).returns "foo"
        @provider = provider_class.new(@resource)
    end

    describe "when flushing" do
        before :each do
            # Stub file and directory operations
            Dir.stubs(:mkdir)
            File.stubs(:chmod)
            File.stubs(:chown)
        end

        describe "and a user has been specified" do
            before :each do
                @resource.stubs(:should).with(:user).returns "nobody"
                target = File.expand_path("~nobody/.ssh/authorized_keys")
                @resource.stubs(:should).with(:target).returns target
           end

            it "should create the directory" do
                Dir.expects(:mkdir).with(File.expand_path("~nobody/.ssh"), 0700)
                @provider.flush
            end

            it "should chown the directory to the user" do
                uid = Puppet::Util.uid("nobody")
                File.expects(:chown).with(uid, nil, File.expand_path("~nobody/.ssh"))
                @provider.flush
            end

            it "should chown the key file to the user" do
                uid = Puppet::Util.uid("nobody")
                File.expects(:chown).with(uid, nil, File.expand_path("~nobody/.ssh/authorized_keys"))
                @provider.flush
            end

            it "should chmod the key file to 0600" do
                File.expects(:chmod).with(0600, File.expand_path("~nobody/.ssh/authorized_keys"))
                @provider.flush
            end
        end

        describe "and a target has been specified" do
            before :each do
                @resource.stubs(:should).with(:user).returns nil
                @resource.stubs(:should).with(:target).returns "/tmp/.ssh/authorized_keys"
            end

            it "should make the directory" do
                Dir.expects(:mkdir).with("/tmp/.ssh", 0755)
                @provider.flush
            end

            it "should chmod the key file to 0644" do
                File.expects(:chmod).with(0644, "/tmp/.ssh/authorized_keys")
                @provider.flush
            end
        end

    end
end

describe provider_class do
    before :each do
        @resource = stub("resource", :name => "foo")
        @resource.stubs(:[]).returns "foo"
        @provider = provider_class.new(@resource)
    end

    describe "when flushing" do
        before :each do
            # Stub file and directory operations
            Dir.stubs(:mkdir)
            File.stubs(:chmod)
            File.stubs(:chown)
        end

        describe "and a user has been specified" do
            before :each do
                @resource.stubs(:should).with(:user).returns "nobody"
                @resource.stubs(:should).with(:target).returns nil
           end

            it "should create the directory" do
                Dir.expects(:mkdir).with(File.expand_path("~nobody/.ssh"), 0700)
                @provider.flush
            end

            it "should chown the directory to the user" do
                uid = Puppet::Util.uid("nobody")
                File.expects(:chown).with(uid, nil, File.expand_path("~nobody/.ssh"))
                @provider.flush
            end

            it "should chown the key file to the user" do
                uid = Puppet::Util.uid("nobody")
                File.expects(:chown).with(uid, nil, File.expand_path("~nobody/.ssh/authorized_keys"))
                @provider.flush
            end

            it "should chmod the key file to 0600" do
                File.expects(:chmod).with(0600, File.expand_path("~nobody/.ssh/authorized_keys"))
                @provider.flush
            end
        end

        describe "and a target has been specified" do
            before :each do
                @resource.stubs(:should).with(:user).returns nil
                @resource.stubs(:should).with(:target).returns "/tmp/.ssh/authorized_keys"
            end

            it "should make the directory" do
                Dir.expects(:mkdir).with("/tmp/.ssh", 0755)
                @provider.flush
            end

            it "should chmod the key file to 0644" do
                File.expects(:chmod).with(0644, "/tmp/.ssh/authorized_keys")
                @provider.flush
            end
        end

    end
end
