#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe Puppet::Type.type(:user), '(integration)', :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  context "when set to purge ssh keys from a file" do
    let(:tempfile) do
      file_containing('user_spec', <<-EOF)
        # comment
        ssh-rsa KEY-DATA key-name
        ssh-rsa KEY-DATA key name
        EOF
    end
    # must use an existing user, or the generated key resource
    # will fail on account of an invalid user for the key
    # - root should be a safe default
    let(:manifest) { "user { 'root': purge_ssh_keys => '#{tempfile}' }" }

    it "should purge authorized ssh keys" do
      apply_compiled_manifest(manifest)
      expect(File.read(tempfile)).not_to match(/key-name/)
    end

    it "should purge keys with spaces in the comment string" do
      apply_compiled_manifest(manifest)
      expect(File.read(tempfile)).not_to match(/key name/)
    end

    context "with other prefetching resources evaluated first" do
      let(:manifest) { "host { 'test': before => User[root] } user { 'root': purge_ssh_keys => '#{tempfile}' }" }

      it "should purge authorized ssh keys" do
        apply_compiled_manifest(manifest)
        expect(File.read(tempfile)).not_to match(/key-name/)
      end
    end

    context "with multiple unnamed keys" do
      let(:tempfile) do
        file_containing('user_spec', <<-EOF)
          # comment
          ssh-rsa KEY-DATA1
          ssh-rsa KEY-DATA2
          EOF
      end

      it "should purge authorized ssh keys" do
        apply_compiled_manifest(manifest)
        expect(File.read(tempfile)).not_to match(/KEY-DATA/)
      end
    end
  end
end
