#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe Puppet::Type.type(:sshkey), '(integration)', :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:target) { tmpfile('ssh_known_hosts') }
  let(:manifest) { "sshkey { 'test':
    ensure => 'present',
    type => 'rsa',
    key => 'TESTKEY',
    target => '#{target}' }"
  }

  it "should create a new known_hosts file with mode 0644" do
    apply_compiled_manifest(manifest)
    expect_file_mode(target, "644")
  end
end
