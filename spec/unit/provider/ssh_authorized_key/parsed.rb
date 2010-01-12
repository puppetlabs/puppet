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
        @provider.stubs(:filetype).returns(Puppet::Util::FileType::FileTypeRam)
        file = @provider.default_target

        key.flush
        text = @provider.target_object(file).read
        return text
    end

    PuppetTest.fakedata("data/providers/ssh_authorized_key/parsed").each { |file|
        it "should be able to parse example data in #{file}" do
            puts "Parsing %s" % file
            fakedataparse(file)
        end
    }

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

    it "should use '' as name for entries that lack a comment" do
        line = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAut8aOSxenjOqF527dlsdHWV4MNoAsX14l9M297+SQXaQ5Z3BedIxZaoQthkDALlV/25A1COELrg9J2MqJNQc8Xe9XQOIkBQWWinUlD/BXwoOTWEy8C8zSZPHZ3getMMNhGTBO+q/O+qiJx3y5cA4MTbw2zSxukfWC87qWwcZ64UUlegIM056vPsdZWFclS9hsROVEa57YUMrehQ1EGxT4Z5j6zIopufGFiAPjZigq/vqgcAqhAKP6yu4/gwO6S9tatBeEjZ8fafvj1pmvvIplZeMr96gHE7xS3pEEQqnB3nd4RY7AF6j9kFixnsytAUO7STPh/M3pLiVQBN89TvWPQ=="

        @provider.parse(line)[0][:name].should == ""
    end
end

describe provider_class do
    before :each do
        @resource = stub("resource", :name => "foo")
        @resource.stubs(:[]).returns "foo"

        @provider = provider_class.new(@resource)
        provider_class.stubs(:filetype).returns(Puppet::Util::FileType::FileTypeRam)
    end

    describe "when flushing" do
        before :each do
            # Stub file and directory operations
            Dir.stubs(:mkdir)
            File.stubs(:chmod)
            File.stubs(:chown)
        end

        describe "and both a user and a target have been specified" do
            before :each do
                Puppet::Util.stubs(:uid).with("random_bob").returns 12345
                @resource.stubs(:should).with(:user).returns "random_bob"
                target = "/tmp/.ssh_dir/place_to_put_authorized_keys"
                @resource.stubs(:should).with(:target).returns target
           end

            it "should create the directory" do
                File.stubs(:exist?).with("/tmp/.ssh_dir").returns false
                Dir.expects(:mkdir).with("/tmp/.ssh_dir", 0700)
                @provider.flush
            end

            it "should chown the directory to the user" do
                uid = Puppet::Util.uid("random_bob")
                File.expects(:chown).with(uid, nil, "/tmp/.ssh_dir")
                @provider.flush
            end

            it "should chown the key file to the user" do
                uid = Puppet::Util.uid("random_bob")
                File.expects(:chown).with(uid, nil, "/tmp/.ssh_dir/place_to_put_authorized_keys")
                @provider.flush
            end

            it "should chmod the key file to 0600" do
                File.expects(:chmod).with(0600, "/tmp/.ssh_dir/place_to_put_authorized_keys")
                @provider.flush
            end
        end

        describe "and a user has been specified with no target" do
            before :each do
                @resource.stubs(:should).with(:user).returns "nobody"
                @resource.stubs(:should).with(:target).returns nil
                # 
                # I'd like to use random_bob here and something like
                #
                #    File.stubs(:expand_path).with("~random_bob/.ssh").returns "/users/r/random_bob/.ssh"
                #
                # but mocha objects strenuously to stubbing File.expand_path
                # so I'm left with using nobody.
                @dir = File.expand_path("~nobody/.ssh")
           end

            it "should create the directory" do
                File.stubs(:exist?).with(@dir).returns false
                Dir.expects(:mkdir).with(@dir,0700)
                @provider.flush
            end

            it "should chown the directory to the user" do
                uid = Puppet::Util.uid("nobody")
                File.expects(:chown).with(uid, nil, @dir)
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

        describe "and a target has been specified with no user" do
            before :each do
                @resource.stubs(:should).with(:user).returns nil
                @resource.stubs(:should).with(:target).returns("/tmp/.ssh_dir/place_to_put_authorized_keys")
            end

            it "should make the directory" do
                File.stubs(:exist?).with("/tmp/.ssh_dir").returns false
                Dir.expects(:mkdir).with("/tmp/.ssh_dir", 0755)
                @provider.flush
            end

            it "should chmod the key file to 0644" do
                File.expects(:chmod).with(0644, "/tmp/.ssh_dir/place_to_put_authorized_keys")
                @provider.flush
            end
        end

    end
end
