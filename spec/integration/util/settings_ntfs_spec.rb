#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/configurer'

# Helper method which calls powershell to retrieve the ACLs of a path
# and return a simple JSON structure, which we can then assert on in
# rspec exmaples.
def with_acl_hash(path, &block)
  # Note - This does not work with paths with a single quote in them
  # Note - ConvertTo-JSON requires PS3 or above
  ps_script = <<-EOT
$Path = '#{path}';
(Get-ACL $Path).access | ForEach-Object {
New-Object -TypeName PSObject -Property @{
  'FileSystemRights' = $_.FileSystemRights.ToString();
  'AccessControlType' = $_.AccessControlType.ToString();
  'IdentityReference' = $_.IdentityReference.Value.ToString();
  'IsInherited' = $_.IsInherited;
  'InheritanceFlags' = $_.InheritanceFlags.ToString();
  'PropagationFlags' = $_.PropagationFlags.ToString();
  'Path' = $Path;
}
} | ConvertTo-JSON
EOT
  cmd = "powershell -NoLogo -NoProfile -NonInteractive -Command \"#{ps_script.gsub("\n","")}\""

  result = %x[ #{cmd} ]
# DEBUG puts "SSSSS #{path}"
  begin
    yield JSON.parse(result)
  rescue JSON::ParserError
    raise "Failed to get ACL of #{path}. #{result}"
  end
end

# Custom matchers for ACL hashes
RSpec::Matchers.define :contain_only_inherited_aces do
  match do |actual|
    find_aces(actual).nil?
  end

  failure_message do |actual|
    "expected that #{find_aces(actual)} would contain only inherited ACEs"
  end

  def find_aces(acl)
    acl.find { |ace| ace['IsInherited'] != true }
  end
end

RSpec::Matchers.define :contain_any_inherited_aces do
  match do |actual|
    !find_aces(actual).nil?
  end

  failure_message do |actual|
    "expected that #{actual[0]['Path']} would contain at least one inherited ACE"
  end

  def find_aces(acl)
    acl.find { |ace| ace['IsInherited'] == true }
  end
end

RSpec::Matchers.define :contain_identity_reference do |identity_reference|
  match do |actual|
    !find_aces(actual, identity_reference).nil?
  end

  failure_message do |actual|
    "expected that #{actual[0]['Path']} would contain at least one ACE for identity #{identity_reference}"
  end

  failure_message_when_negated do |actual|
    "expected that #{find_aces(actual, identity_reference)} would not contain an ACE for identity #{identity_reference}"
  end

  def find_aces(acl, identity_reference)
    acl.find { |ace| ace['IdentityReference'].casecmp(identity_reference) == 0 }
  end
end

# Default config settings are stored in
# /lib/puppet/defaults.rb
def default_directory_settings
  [:pluginfactdest, :libdir, :localedest]
end

def protected_directory_settings
  [:logdir, :preview_outputdir, :rundir, :statedir, :reportdir]
end

# def all_directory_settings
#   default_directory_settings + protected_directory_settings
# end

# TODO Can I fudge the root? feature "(Puppet.features.stubs(:root?).returns true" to make it
# change run_mode?

describe Puppet::Settings do
  include PuppetSpec::Files

  describe "when applying the catalog generated from Puppet.settings", :if => Puppet.features.microsoft_windows? do
    #let(:settings) { Puppet::Settings.new }

    before(:each) do
      # Create the settings catalog and apply it
      catalog = Puppet.settings.to_catalog
      catalog = catalog.to_ral
      configurer = Puppet::Configurer.new
      # Run the configurer until it returns 2 (No changes made)
      # Don't know why though.  It shouldn't take multiple attempts!
      result = configurer.run(:catalog => catalog, :pluginsync => false)
      result = configurer.run(:catalog => catalog, :pluginsync => false) if result != 2
      result = configurer.run(:catalog => catalog, :pluginsync => false) if result != 2
      catalog.finalize
      # DEBUG puts "confdir = #{Puppet.settings[:confdir]}"
      # DEBUG puts catalog.resource_keys
    end

    it 'should create folder structure with correct inheritance' do
      # Default directories
      default_directory_settings.each do |setting|
        with_acl_hash(Puppet.settings[setting]) do |acl|
          expect(acl).to contain_only_inherited_aces
        end
      end

      # Protected directories
      protected_directory_settings.each do |setting|
        with_acl_hash(Puppet.settings[setting]) do |acl|
          expect(acl).not_to contain_any_inherited_aces
        end
      end
    end

    it 'should not add the NT AUTHORITY\\SYSTEM account, but should add BUILTIN\\Administrators' do
      pending('PUP-6729 should resolve this')

      protected_directory_settings.each do |setting|
        with_acl_hash(Puppet.settings[setting]) do |acl|
          expect(acl).not_to contain_identity_reference('NT AUTHORITY\\SYSTEM')
          expect(acl).to contain_identity_reference('BUILTIN\\Administrators')
        end
      end
    end
  end
end
