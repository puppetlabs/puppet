#!/usr/bin/env rspec
require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'
require 'puppet_spec/files'

provider_class = Puppet::Type.type(:ssh_authorized_key).provider(:parsed)

describe provider_class do
  include PuppetSpec::Files

  before :each do
    @keyfile = tmpfile('authorized_keys')
    @provider_class = provider_class
    @provider_class.initvars
    @provider_class.any_instance.stubs(:target).returns @keyfile
    @user = 'random_bob'
    Puppet::Util.stubs(:uid).with(@user).returns 12345
  end

  def mkkey(args)
    args[:target] = @keyfile
    args[:user]   = @user
    resource = Puppet::Type.type(:ssh_authorized_key).new(args)
    key = @provider_class.new(resource)
    args.each do |p,v|
      key.send(p.to_s + "=", v)
    end
    key
  end

  def genkey(key)
    @provider_class.stubs(:filetype).returns(Puppet::Util::FileType::FileTypeRam)
    File.stubs(:chown)
    File.stubs(:chmod)
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    key.flush
    @provider_class.target_object(@keyfile).read
  end

  it_should_behave_like "all parsedfile providers", provider_class

  it "should be able to generate a basic authorized_keys file" do

    key = mkkey(:name    => "Just_Testing",
                :key     => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
                :type    => "ssh-dss",
                :ensure  => :present,
                :options => [:absent]
              )

    genkey(key).should == "ssh-dss AAAAfsfddsjldjgksdflgkjsfdlgkj Just_Testing\n"
  end

  it "should be able to generate a authorized_keys file with options" do

    key = mkkey(:name    => "root@localhost",
                :key     => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
                :type    => "ssh-rsa",
                :ensure  => :present,
                :options => ['from="192.168.1.1"', "no-pty", "no-X11-forwarding"]
                )

    genkey(key).should == "from=\"192.168.1.1\",no-pty,no-X11-forwarding ssh-rsa AAAAfsfddsjldjgksdflgkjsfdlgkj root@localhost\n"
  end

  it "should be able to parse options containing commas via its parse_options method" do
    options = %w{from="host1.reductlivelabs.com,host.reductivelabs.com" command="/usr/local/bin/run" ssh-pty}
    optionstr = options.join(", ")

    @provider_class.parse_options(optionstr).should == options
  end

  it "should use '' as name for entries that lack a comment" do
    line = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAut8aOSxenjOqF527dlsdHWV4MNoAsX14l9M297+SQXaQ5Z3BedIxZaoQthkDALlV/25A1COELrg9J2MqJNQc8Xe9XQOIkBQWWinUlD/BXwoOTWEy8C8zSZPHZ3getMMNhGTBO+q/O+qiJx3y5cA4MTbw2zSxukfWC87qWwcZ64UUlegIM056vPsdZWFclS9hsROVEa57YUMrehQ1EGxT4Z5j6zIopufGFiAPjZigq/vqgcAqhAKP6yu4/gwO6S9tatBeEjZ8fafvj1pmvvIplZeMr96gHE7xS3pEEQqnB3nd4RY7AF6j9kFixnsytAUO7STPh/M3pLiVQBN89TvWPQ=="

    @provider_class.parse(line)[0][:name].should == ""
  end
end

describe provider_class do
  before :each do
    @resource = Puppet::Type.type(:ssh_authorized_key).new(:name => "foo", :user => "random_bob")

    @provider = provider_class.new(@resource)
    provider_class.stubs(:filetype).returns(Puppet::Util::FileType::FileTypeRam)
    Puppet::Util::SUIDManager.stubs(:asuser).yields

    provider_class.initvars
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
        @resource[:user] = "random_bob"
        target = "/tmp/.ssh_dir/place_to_put_authorized_keys"
        @resource[:target] = target
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
        @resource[:user] = "nobody"
        #
        # I'd like to use random_bob here and something like
        #
        #    File.stubs(:expand_path).with("~random_bob/.ssh").returns "/users/r/random_bob/.ssh"
        #
        # but mocha objects strenuously to stubbing File.expand_path
        # so I'm left with using nobody.
        @dir = File.expand_path("~nobody/.ssh")
      end

      it "should create the directory if it doesn't exist" do
        File.stubs(:exist?).with(@dir).returns false
        Dir.expects(:mkdir).with(@dir,0700)
        @provider.flush
      end

      it "should not create or chown the directory if it already exist" do
        File.stubs(:exist?).with(@dir).returns false
        Dir.expects(:mkdir).never
        @provider.flush
      end

      it "should chown the directory to the user if it creates it" do
        File.stubs(:exist?).with(@dir).returns false
        Dir.stubs(:mkdir).with(@dir,0700)
        uid = Puppet::Util.uid("nobody")
        File.expects(:chown).with(uid, nil, @dir)
        @provider.flush
      end

      it "should not create or chown the directory if it already exist" do
        File.stubs(:exist?).with(@dir).returns false
        Dir.expects(:mkdir).never
        File.expects(:chown).never
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
      it "should raise an error" do
        @resource = Puppet::Type.type(:ssh_authorized_key).new(:name => "foo", :target => "/tmp/.ssh_dir/place_to_put_authorized_keys")
        @provider = provider_class.new(@resource)

        proc { @provider.flush }.should raise_error
      end
    end

    describe "and a invalid user has been specified with no target" do
      it "should catch an exception and raise a Puppet error" do
        @resource[:user] = "thisusershouldnotexist"

        lambda { @provider.flush }.should raise_error(Puppet::Error)
      end
    end
  end
end
