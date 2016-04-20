#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/auth_config_parser'
require 'puppet/network/authconfig'

describe Puppet::Network::AuthConfigParser do
  include PuppetSpec::Files

  let(:fake_authconfig) do
    "path ~ ^/catalog/([^/])\nmethod find\nallow *\n"
  end

  describe "Basic Parser" do
    it "should accept a string by default" do
      expect(described_class.new(fake_authconfig).parse).to be_a_kind_of Puppet::Network::AuthConfig
    end
  end

  describe "when parsing rights" do
    it "skips comments" do
      expect(described_class.new('  # comment\n').parse_rights).to be_empty
    end

    it "increments line number even on commented lines" do
      expect(described_class.new("  # comment\npath /").parse_rights['/'].line).to eq(2)
    end

    it "skips blank lines" do
      expect(described_class.new('  ').parse_rights).to be_empty
    end

    it "increments line number even on blank lines" do
      expect(described_class.new("  \npath /").parse_rights['/'].line).to eq(2)
    end

    it "does not throw an error if the same path appears twice" do
      expect {
        described_class.new("path /hello\npath /hello").parse_rights
      }.to_not raise_error
    end

    it "should create a new right for each found path line" do
      expect(described_class.new('path /certificates').parse_rights['/certificates']).to be
    end

    it "should create a new right for each found regex line" do
      expect(described_class.new('path ~ .rb$').parse_rights['.rb$']).to be
    end

    it "should strip whitespace around ACE" do
      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('127.0.0.1')
      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('172.16.10.0')

      described_class.new("path /\n allow 127.0.0.1 , 172.16.10.0  ").parse_rights
    end

    it "should allow ACE inline comments" do

      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('127.0.0.1')

      described_class.new("path /\n allow 127.0.0.1 # will it work?").parse_rights
    end

    it "should create an allow ACE on each subsequent allow" do
      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('127.0.0.1')

      described_class.new("path /\nallow 127.0.0.1").parse_rights
    end

    it "should create a deny ACE on each subsequent deny" do
      Puppet::Network::Rights::Right.any_instance.expects(:deny).with('127.0.0.1')

      described_class.new("path /\ndeny 127.0.0.1").parse_rights
    end

    it "should inform the current ACL if we get the 'method' directive" do
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_method).with('search')
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_method).with('find')

      described_class.new("path /certificates\nmethod search,find").parse_rights
    end

    it "should inform the current ACL if we get the 'environment' directive" do
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_environment).with('production')
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_environment).with('development')

      described_class.new("path /certificates\nenvironment production,development").parse_rights
    end

    it "should inform the current ACL if we get the 'auth' directive" do
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_authenticated).with('yes')

      described_class.new("path /certificates\nauth yes").parse_rights
    end

    it "should also allow the long form 'authenticated' directive" do
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_authenticated).with('yes')

      described_class.new("path /certificates\nauthenticated yes").parse_rights
    end
  end

  describe "when parsing rights from files" do
    it "can read UTF-8" do
      rune_path = "/\u16A0\u16C7\u16BB" # ᚠᛇᚻ
      config = tmpfile('config')

      File.open(config, 'w', :encoding => 'utf-8') do |file|
        file.puts <<-EOF
path #{rune_path}
      EOF
    end

      expect(described_class.new_from_file(config).parse_rights[rune_path]).to be
    end
  end
end
