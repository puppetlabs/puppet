#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/file_bucket/dipper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe Puppet::Type.type(:sshkey).provider(:parsed), '(integration)',
  :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  before :each do
    # Don't backup to filebucket
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup)
    # We don't want to execute anything
    described_class.stubs(:filetype).
      returns Puppet::Util::FileType::FileTypeFlat

    @sshkey_file = tmpfile('sshkey_integration_specs')
    FileUtils.cp(my_fixture('sample'), @sshkey_file)
  end

  after :each do
    # sshkey provider class
    described_class.clear
  end

  let(:type_under_test) { 'sshkey' }

  describe "when managing a ssh known hosts file it..." do

    let(:super_unique) { "my.super.unique.host" }
    it "should create a new known_hosts file with mode 0644" do
      target   = tmpfile('ssh_known_hosts')
      manifest = "#{type_under_test} { '#{super_unique}':
                    ensure => 'present',
                    type   => 'rsa',
                    key    => 'TESTKEY',
                    target => '#{target}' }"
      apply_with_error_check(manifest)
      expect_file_mode(target, "644")
    end

    it "should create an SSH host key entry (ensure present)" do
      manifest = "#{type_under_test} { '#{super_unique}':
                    ensure => 'present',
                    type   => 'rsa',
                    key    => 'mykey',
                    target => '#{@sshkey_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(@sshkey_file)).to match(/#{super_unique}.*mykey/)
    end

    let(:sshkey_name) { 'kirby.madstop.com' }
    it "should delete an entry for an SSH host key" do
      manifest = "#{type_under_test} { '#{sshkey_name}':
                    ensure => 'absent',
                    target => '#{@sshkey_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(@sshkey_file)).not_to match(/#{sshkey_name}.*Yqk0=/)
    end

    it "should update an entry for an SSH host key" do
      manifest = "#{type_under_test} { '#{sshkey_name}':
                    ensure => 'present',
                    type   => 'rsa',
                    key    => 'mynewshinykey',
                    target => '#{@sshkey_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(@sshkey_file)).to match(/#{sshkey_name}.*mynewshinykey/)
      expect(File.read(@sshkey_file)).not_to match(/#{sshkey_name}.*Yqk0=/)
    end

    # test all key types
    types = ["ssh-dss",     "dsa",
             "ssh-ed25519", "ed25519",
             "ssh-rsa",     "rsa",
             "ecdsa-sha2-nistp256",
             "ecdsa-sha2-nistp384",
             "ecdsa-sha2-nistp521"]
    # these types are treated as aliases for sshkey <ahem> type
    #   so they are populated as the *values* below
    aliases = {"dsa"     => "ssh-dss",
               "ed25519" => "ssh-ed25519",
               "rsa"     => "ssh-rsa"}
    types.each do |type|
      it "should update an entry with #{type} type" do
        manifest = "#{type_under_test} { '#{sshkey_name}':
                      ensure => 'present',
                      type   => '#{type}',
                      key    => 'mynewshinykey',
                      target => '#{@sshkey_file}' }"

        apply_with_error_check(manifest)
        if aliases.has_key?(type)
          full_type = aliases[type]
          expect(File.read(@sshkey_file)).
            to match(/#{sshkey_name}.*#{full_type}.*mynew/)
        else
          expect(File.read(@sshkey_file)).
            to match(/#{sshkey_name}.*#{type}.*mynew/)
        end
      end
    end

    # test unknown key type fails
    let(:invalid_type) { 'ssh-er0ck' }
    it "should raise an error with an unknown type" do
      manifest = "#{type_under_test} { '#{sshkey_name}':
                    ensure => 'present',
                    type   => '#{invalid_type}',
                    key    => 'mynewshinykey',
                    target => '#{@sshkey_file}' }"
      expect {
      apply_compiled_manifest(manifest)
      }.to raise_error(Puppet::ResourceError, /Invalid value "#{invalid_type}"/)
    end

    #single host_alias
    let(:host_alias) { 'r0ckdata.com' }
    it "should update an entry with new host_alias" do
      manifest = "#{type_under_test} { '#{sshkey_name}':
                    ensure       => 'present',
                    host_aliases => '#{host_alias}',
                    target       => '#{@sshkey_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(@sshkey_file)).to match(/#{sshkey_name},#{host_alias}\s/)
      expect(File.read(@sshkey_file)).not_to match(/#{sshkey_name}\s/)
    end

    #array host_alias
    let(:host_aliases) { "r0ckdata.com,erict.net" }
    it "should update an entry with new host_alias" do
      manifest = "#{type_under_test} { '#{sshkey_name}':
                    ensure       => 'present',
                    host_aliases => '#{host_alias}',
                    target       => '#{@sshkey_file}' }"
      apply_with_error_check(manifest)
      expect(File.read(@sshkey_file)).to match(/#{sshkey_name},#{host_alias}\s/)
      expect(File.read(@sshkey_file)).not_to match(/#{sshkey_name}\s/)
    end

    #puppet resource sshkey
    it "should fetch an entry from resources" do
      @resource_app = Puppet::Application[:resource]
      @resource_app.preinit
      @resource_app.command_line.stubs(:args).
        returns([type_under_test, sshkey_name, "target=#{@sshkey_file}"])

      @resource_app.expects(:puts).with do |args|
        expect(args).to match(/#{sshkey_name}/)
      end
      @resource_app.main
    end

  end

end
