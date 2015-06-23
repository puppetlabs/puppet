#! /usr/bin/env ruby
require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'
require 'puppet_spec/files'

provider_class = Puppet::Type.type(:ssh_authorized_key).provider(:parsed)

describe provider_class, :unless => Puppet.features.microsoft_windows? do
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

    expect(genkey(key)).to eq("ssh-dss AAAAfsfddsjldjgksdflgkjsfdlgkj Just_Testing\n")
  end

  it "should be able to generate an authorized_keys file with options" do

    key = mkkey(:name    => "root@localhost",
                :key     => "AAAAfsfddsjldjgksdflgkjsfdlgkj",
                :type    => "ssh-rsa",
                :ensure  => :present,
                :options => ['from="192.168.1.1"', "no-pty", "no-X11-forwarding"]
                )

    expect(genkey(key)).to eq("from=\"192.168.1.1\",no-pty,no-X11-forwarding ssh-rsa AAAAfsfddsjldjgksdflgkjsfdlgkj root@localhost\n")
  end

  it "should parse comments" do
    result = [{ :record_type => :comment, :line => "# hello" }]
    expect(@provider_class.parse("# hello\n")).to eq(result)
  end

  it "should parse comments with leading whitespace" do
    result = [{ :record_type => :comment, :line => "  # hello" }]
    expect(@provider_class.parse("  # hello\n")).to eq(result)
  end

  it "should skip over lines with only whitespace" do
    result = [{ :record_type => :comment, :line => "#before" },
              { :record_type => :blank,   :line => "  " },
              { :record_type => :comment, :line => "#after" }]
    expect(@provider_class.parse("#before\n  \n#after\n")).to eq(result)
  end

  it "should skip over completely empty lines" do
    result = [{ :record_type => :comment, :line => "#before"},
              { :record_type => :blank,   :line => ""},
              { :record_type => :comment, :line => "#after"}]
    expect(@provider_class.parse("#before\n\n#after\n")).to eq(result)
  end

  it "should be able to parse name if it includes whitespace" do
    expect(@provider_class.parse_line('ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQC7pHZ1XRj3tXbFpPFhMGU1bVwz7jr13zt/wuE+pVIJA8GlmHYuYtIxHPfDHlkixdwLachCpSQUL9NbYkkRFRn9m6PZ7125ohE4E4m96QS6SGSQowTiRn4Lzd9LV38g93EMHjPmEkdSq7MY4uJEd6DUYsLvaDYdIgBiLBIWPA3OrQ== fancy user')[:name]).to eq('fancy user')
    expect(@provider_class.parse_line('from="host1.reductlivelabs.com,host.reductivelabs.com",command="/usr/local/bin/run",ssh-pty ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQC7pHZ1XRj3tXbFpPFhMGU1bVwz7jr13zt/wuE+pVIJA8GlmHYuYtIxHPfDHlkixdwLachCpSQUL9NbYkkRFRn9m6PZ7125ohE4E4m96QS6SGSQowTiRn4Lzd9LV38g93EMHjPmEkdSq7MY4uJEd6DUYsLvaDYdIgBiLBIWPA3OrQ== fancy user')[:name]).to eq('fancy user')
  end

  it "should be able to parse options containing commas via its parse_options method" do
    options = %w{from="host1.reductlivelabs.com,host.reductivelabs.com" command="/usr/local/bin/run" ssh-pty}
    optionstr = options.join(", ")

    expect(@provider_class.parse_options(optionstr)).to eq(options)
  end

  it "should parse quoted options" do
    line = 'command="/usr/local/bin/mybin \"$SSH_ORIGINAL_COMMAND\"" ssh-rsa xxx mykey'

    expect(@provider_class.parse(line)[0][:options][0]).to eq('command="/usr/local/bin/mybin \"$SSH_ORIGINAL_COMMAND\""')
  end

  it "should use '' as name for entries that lack a comment" do
    line = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAut8aOSxenjOqF527dlsdHWV4MNoAsX14l9M297+SQXaQ5Z3BedIxZaoQthkDALlV/25A1COELrg9J2MqJNQc8Xe9XQOIkBQWWinUlD/BXwoOTWEy8C8zSZPHZ3getMMNhGTBO+q/O+qiJx3y5cA4MTbw2zSxukfWC87qWwcZ64UUlegIM056vPsdZWFclS9hsROVEa57YUMrehQ1EGxT4Z5j6zIopufGFiAPjZigq/vqgcAqhAKP6yu4/gwO6S9tatBeEjZ8fafvj1pmvvIplZeMr96gHE7xS3pEEQqnB3nd4RY7AF6j9kFixnsytAUO7STPh/M3pLiVQBN89TvWPQ=="

    expect(@provider_class.parse(line)[0][:name]).to eq("")
  end

  {
    # ssh-keygen -t dsa -b 1024
    'ssh-dss' => 'AAAAB3NzaC1kc3MAAACBANGTefWMXS780qLMMgysq3GNMKzg55LXZODif6Tqv1vtTh4Wuk3J5X5u644jTyNdAIn1RiBI9MnwnZMZ6nXKvucMcMQWMibYS9W2MhkRj3oqsLWMMsdGXJL18SWM5A6oC3oIRC4JHJZtkm0OctR2trKxmX+MGhdCd+Xpsh9CNK8XAAAAFQD4olFiwv+QQUFdaZbWUy1CLEG9xQAAAIByCkXKgoriZF8bQ0OX1sKuR69M/6n5ngmQGVBKB7BQkpUjbK/OggB6iJgst5utKkDcaqYRnrTYG9q3jJ/flv7yYePuoSreS0nCMMx9gpEYuq+7Sljg9IecmN/IHrNd9qdYoASy5iuROQMvEZM7KFHA8vBv0tWdBOsp4hZKyiL1DAAAAIEAjkZlOps9L+cD/MTzxDj7toYYypdLOvjlcPBaglkPZoFZ0MAKTI0zXlVX1cWAnkd0Yfo4EpP+6XAjlZkod+QXKXM4Tb4PnR34ASMeU6sEjM61Na24S7JD3gpPKataFU/oH3hzXsBdK2ttKYmoqvf61h32IA/3Z5PjCCD9pPLPpAY',
    # ssh-keygen -t rsa -b 2048
    'ssh-rsa' => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQDYtEaWa1mlxaAh9vtiz6RCVKDiJHDY15nsqqWU7F7A1+U1498+sWDyRDkZ8vXWQpzyOMBzBSHIxhsprlKhkjomy8BuJP+bHDBIKx4zgSFDrklrPIf467Iuug8J0qqDLxO4rOOjeAiLEyC0t2ZGnsTEea+rmat0bJ2cv3g5L4gH/OFz2pI4ZLp1HGN83ipl5UH8CjXQKwo3Db1E3WJCqKgszVX0Z4/qjnBRxFMoqky/1mGb/mX1eoT9JyQ8OhU9uENZOShkksSpgUqjlrjpj0Yd14hBlnE3M18pE4ivxjzectA/XRKNZaxOL1YREtU8sXusAwmlEY4aJ64aR0JrXfgx',
    # ssh-keygen -t ecdsa -b 256
    'ecdsa-sha2-nistp256' => 'AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBO5PfBf0c2jAuqD+Lj3j+SuXOXNT2uqESLVOn5jVQfEF9GzllOw+CMOpUvV1CiOOn+F1ET15vcsfmD7z05WUTA=',
    # ssh-keygen -t ecdsa -b 384
    'ecdsa-sha2-nistp384' => 'AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBJIfxNoVK4FX3RuMlkHOwwxXwAh6Fqx5uAp4ftXrJ+64qYuIzb+/zSAkJV698Sre1b1lb0G4LyDdVAvXwaYK9kN25vy8umV3WdfZeHKXJGCcrplMCbbOERWARlpiPNEblg==',
    # ssh-keygen -t ecdsa -b 521
    'ecdsa-sha2-nistp521' => 'AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBADLK+u12xwB0JOwpmaxYXv8KnPK4p+SE2405qoo+vpAQ569fMwPMgKzltd770amdeuFogw/MJu17PN9LDdrD3o0uwHMjWee6TpHQDkuEetaxiou6K0WAzgbxx9QsY0MsJgXf1BuMLqdK+xT183wOSXwwumv99G7T32dOJZ5tYrH0y4XMw==',
    # ssh-keygen -t ed25519
    'ssh-ed25519' => 'AAAAC3NzaC1lZDI1NTE5AAAAIBWvu7D1KHBPaNXQcEuBsp48+JyPelXAq8ds6K5Du9gd',
  }.each_pair do |keytype, keydata|
    it "should be able to parse a #{keytype} key entry" do
      comment = 'sample_key'

      record = @provider_class.parse_line("#{keytype} #{keydata} #{comment}")
      expect(record).not_to be_nil
      expect(record[:name]).to eq(comment)
      expect(record[:key]).to eq(keydata)
      expect(record[:type]).to eq(keytype)
    end
  end

  describe "prefetch_hook" do
    let(:path) { '/path/to/keyfile' }
    let(:input) do
      { :type        => 'rsa',
        :key         => 'KEYDATA',
        :name        => '',
        :record_type => :parsed,
        :target      => path,
      }
    end
    it "adds an indexed name to unnamed resources" do
      expect(@provider_class.prefetch_hook([input])[0][:name]).to match(/^#{path}:unnamed-\d+/)
    end
  end

end

describe provider_class, :unless => Puppet.features.microsoft_windows? do
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
        Puppet::FileSystem.stubs(:exist?).with("/tmp/.ssh_dir").returns false
        Dir.expects(:mkdir).with("/tmp/.ssh_dir", 0700)
        @provider.flush
      end

      it "should absolutely not chown the directory to the user" do
        uid = Puppet::Util.uid("random_bob")
        File.expects(:chown).never
        @provider.flush
      end

      it "should absolutely not chown the key file to the user" do
        uid = Puppet::Util.uid("random_bob")
        File.expects(:chown).never
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
        Puppet::FileSystem.stubs(:exist?).with(@dir).returns false
        Dir.expects(:mkdir).with(@dir,0700)
        @provider.flush
      end

      it "should not create or chown the directory if it already exist" do
        Puppet::FileSystem.stubs(:exist?).with(@dir).returns false
        Dir.expects(:mkdir).never
        @provider.flush
      end

      it "should absolutely not chown the directory to the user if it creates it" do
        Puppet::FileSystem.stubs(:exist?).with(@dir).returns false
        Dir.stubs(:mkdir).with(@dir,0700)
        uid = Puppet::Util.uid("nobody")
        File.expects(:chown).never
        @provider.flush
      end

      it "should not create or chown the directory if it already exist" do
        Puppet::FileSystem.stubs(:exist?).with(@dir).returns false
        Dir.expects(:mkdir).never
        File.expects(:chown).never
        @provider.flush
      end

      it "should absolutely not chown the key file to the user" do
        uid = Puppet::Util.uid("nobody")
        File.expects(:chown).never
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

        expect { @provider.flush }.to raise_error(Puppet::Error, /Cannot write SSH authorized keys without user/)
      end
    end

    describe "and an invalid user has been specified with no target" do
      it "should catch an exception and raise a Puppet error" do
        @resource[:user] = "thisusershouldnotexist"

        expect { @provider.flush }.to raise_error(Puppet::Error)
      end
    end
  end
end
