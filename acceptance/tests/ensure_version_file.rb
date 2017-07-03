require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

tag 'audit:high',
    'audit:acceptance',
    'audit:refactor'  # This should be folded into `ensure_puppet-agent_paths` test

# ensure a version file is created according to the puppet-agent path specification:
# https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md

test_name 'PA-466: Ensure version file is created on agent' do

  skip_test 'requires version file which is created by AIO' if @options[:type] != 'aio'

  step "test for existence of version file" do
    agents.each do |agent|
      platform = agent[:platform]
      ruby_arch = agent[:ruby_arch] || 'x86' # ruby_arch defaults to x86 if nil

      if platform =~ /windows/
        version_file = platform =~ /-64$/ && ruby_arch == 'x86' ?
          "C:/Program Files (x86)/Puppet Labs/Puppet/VERSION" :
          "C:/Program Files/Puppet Labs/Puppet/VERSION"
      else
        version_file = "/opt/puppetlabs/puppet/VERSION"
      end

      if !file_exists?(agent, version_file)
        fail_test("Failed to find version file #{version_file} on agent #{agent}")
      end
    end
  end
end

