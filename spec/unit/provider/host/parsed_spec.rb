#! /usr/bin/env ruby
require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'

require 'puppet_spec/files'

provider_class = Puppet::Type.type(:host).provider(:parsed)

describe provider_class do
  include PuppetSpec::Files

  before do
    @host_class = Puppet::Type.type(:host)
    @provider = @host_class.provider(:parsed)
    @hostfile = tmpfile('hosts')
    @provider.any_instance.stubs(:target).returns @hostfile
  end

  after :each do
    @provider.initvars
  end

  def mkhost(args)
    hostresource = Puppet::Type::Host.new(:name => args[:name])
    hostresource.stubs(:should).with(:target).returns @hostfile

    # Using setters of provider to build our testobject
    # Note: We already proved, that in case of host_aliases
    # the provider setter "host_aliases=(value)" will be
    # called with the joined array, so we just simulate that
    host = @provider.new(hostresource)
    args.each do |property,value|
      value = value.join(" ") if property == :host_aliases and value.is_a?(Array)
      host.send("#{property}=", value)
    end
    host
  end

  def genhost(host)
    @provider.stubs(:filetype).returns(Puppet::Util::FileType::FileTypeRam)
    File.stubs(:chown)
    File.stubs(:chmod)
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    host.flush
    @provider.target_object(@hostfile).read
  end

  describe "when parsing on incomplete line" do

    it "should work for only ip" do
      expect(@provider.parse_line("127.0.0.1")[:line]).to eq("127.0.0.1")
    end

    it "should work for only hostname" do
      expect(@provider.parse_line("www.example.com")[:line]).to eq("www.example.com")
    end

    it "should work for ip and space" do
      expect(@provider.parse_line("127.0.0.1 ")[:line]).to eq("127.0.0.1 ")
    end

    it "should work for hostname and space" do
      expect(@provider.parse_line("www.example.com ")[:line]).to eq("www.example.com ")
    end

    it "should work for hostname and host_aliases" do
      expect(@provider.parse_line("www.example.com  www xyz")[:line]).to eq("www.example.com  www xyz")
    end

    it "should work for ip and comment" do
      expect(@provider.parse_line("127.0.0.1  #www xyz")[:line]).to eq("127.0.0.1  #www xyz")
    end

    it "should work for hostname and comment" do
      expect(@provider.parse_line("xyz  #www test123")[:line]).to eq("xyz  #www test123")
    end

    it "should work for crazy incomplete lines" do
      expect(@provider.parse_line("%th1s is a\t cr$zy    !incompl1t line")[:line]).to eq("%th1s is a\t cr$zy    !incompl1t line")
    end

  end

  describe "when parsing a line with ip and hostname" do

    it "should parse an ipv4 from the first field" do
      expect(@provider.parse_line("127.0.0.1    localhost")[:ip]).to eq("127.0.0.1")
    end

    it "should parse an ipv6 from the first field" do
      expect(@provider.parse_line("::1     localhost")[:ip]).to eq("::1")
    end

    it "should parse the name from the second field" do
      expect(@provider.parse_line("::1     localhost")[:name]).to eq("localhost")
    end

    it "should set an empty comment" do
      expect(@provider.parse_line("::1     localhost")[:comment]).to eq("")
    end

    it "should set host_aliases to :absent" do
      expect(@provider.parse_line("::1     localhost")[:host_aliases]).to eq(:absent)
    end

  end

  describe "when parsing a line with ip, hostname and comment" do
    before do
      @testline = "127.0.0.1   localhost # A comment with a #-char"
    end

    it "should parse the ip from the first field" do
      expect(@provider.parse_line(@testline)[:ip]).to eq("127.0.0.1")
    end

    it "should parse the hostname from the second field" do
      expect(@provider.parse_line(@testline)[:name]).to eq("localhost")
    end

    it "should parse the comment after the first '#' character" do
      expect(@provider.parse_line(@testline)[:comment]).to eq('A comment with a #-char')
    end

  end

  describe "when parsing a line with ip, hostname and aliases" do

    it "should parse alias from the third field" do
      expect(@provider.parse_line("127.0.0.1   localhost   localhost.localdomain")[:host_aliases]).to eq("localhost.localdomain")
    end

    it "should parse multiple aliases" do
      expect(@provider.parse_line("127.0.0.1 host alias1 alias2")[:host_aliases]).to eq('alias1 alias2')
      expect(@provider.parse_line("127.0.0.1 host alias1\talias2")[:host_aliases]).to eq('alias1 alias2')
      expect(@provider.parse_line("127.0.0.1 host alias1\talias2   alias3")[:host_aliases]).to eq('alias1 alias2 alias3')
    end

  end

  describe "when parsing a line with ip, hostname, aliases and comment" do

    before do
      # Just playing with a few different delimiters
      @testline = "127.0.0.1\t   host  alias1\talias2   alias3   #   A comment with a #-char"
    end

    it "should parse the ip from the first field" do
      expect(@provider.parse_line(@testline)[:ip]).to eq("127.0.0.1")
    end

    it "should parse the hostname from the second field" do
      expect(@provider.parse_line(@testline)[:name]).to eq("host")
    end

    it "should parse all host_aliases from the third field" do
      expect(@provider.parse_line(@testline)[:host_aliases]).to eq('alias1 alias2 alias3')
    end

    it "should parse the comment after the first '#' character" do
      expect(@provider.parse_line(@testline)[:comment]).to eq('A comment with a #-char')
    end

  end

  describe "when operating on /etc/hosts like files" do
    it_should_behave_like "all parsedfile providers",
      provider_class, my_fixtures('valid*')

    it "should be able to generate a simple hostfile entry" do
      host = mkhost(
        :name   => 'localhost',
        :ip     => '127.0.0.1',
        :ensure => :present
      )
      expect(genhost(host)).to eq("127.0.0.1\tlocalhost\n")
    end

    it "should be able to generate an entry with one alias" do
      host = mkhost(
        :name   => 'localhost.localdomain',
        :ip     => '127.0.0.1',
        :host_aliases => 'localhost',
        :ensure => :present
      )
      expect(genhost(host)).to eq("127.0.0.1\tlocalhost.localdomain\tlocalhost\n")
    end

    it "should be able to generate an entry with more than one alias" do
      host = mkhost(
        :name       => 'host',
        :ip         => '192.0.0.1',
        :host_aliases => [ 'a1','a2','a3','a4' ],
        :ensure     => :present
      )
      expect(genhost(host)).to eq("192.0.0.1\thost\ta1 a2 a3 a4\n")
    end

    it "should be able to generate a simple hostfile entry with comments" do
      host = mkhost(
        :name    => 'localhost',
        :ip      => '127.0.0.1',
        :comment => 'Bazinga!',
        :ensure  => :present
      )
      expect(genhost(host)).to eq("127.0.0.1\tlocalhost\t# Bazinga!\n")
    end

    it "should be able to generate an entry with one alias and a comment" do
      host = mkhost(
        :name   => 'localhost.localdomain',
        :ip     => '127.0.0.1',
        :host_aliases => 'localhost',
        :comment => 'Bazinga!',
        :ensure => :present
      )
      expect(genhost(host)).to eq("127.0.0.1\tlocalhost.localdomain\tlocalhost\t# Bazinga!\n")
    end

    it "should be able to generate an entry with more than one alias and a comment" do
      host = mkhost(
        :name         => 'host',
        :ip           => '192.0.0.1',
        :host_aliases => [ 'a1','a2','a3','a4' ],
        :comment      => 'Bazinga!',
        :ensure       => :present
      )
      expect(genhost(host)).to eq("192.0.0.1\thost\ta1 a2 a3 a4\t# Bazinga!\n")
    end

  end

end
