# ensure installs and code honor new puppet-agent path spec:
# https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md
test_name 'PUP-4033: Ensure aio path spec is honored'

# include file_exists?
require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

config_options = [
  # code
  {:name => :codedir, :posix_expected => '/etc/puppetlabs/code', :win_expected => 'C:/ProgramData/PuppetLabs/code', :installed => :dir},
  {:name => :environmentpath, :posix_expected => '/etc/puppetlabs/code/environments', :win_expected => 'C:/ProgramData/PuppetLabs/code/environments'},
  {:name => :hiera_config, :posix_expected => '/etc/puppetlabs/code/hiera.yaml', :win_expected => 'C:/ProgramData/PuppetLabs/code/hiera.yaml'},

  # confdir
  {:name => :confdir, :posix_expected => '/etc/puppetlabs/puppet', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc', :installed => :dir},
  {:name => :rest_authconfig, :posix_expected => '/etc/puppetlabs/puppet/auth.conf', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/auth.conf'},
  {:name => :autosign, :posix_expected => '/etc/puppetlabs/puppet/autosign.conf', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/autosign.conf'},
  {:name => :binder_config, :posix_expected => '', :win_expected => ''},
  {:name => :csr_attributes, :posix_expected => '/etc/puppetlabs/puppet/csr_attributes.yaml', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/csr_attributes.yaml'},
  {:name => :trusted_oid_mapping_file, :posix_expected => '/etc/puppetlabs/puppet/custom_trusted_oid_mapping.yaml', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/custom_trusted_oid_mapping.yaml'},
  {:name => :deviceconfig, :posix_expected => '/etc/puppetlabs/puppet/device.conf', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/device.conf'},
  {:name => :fileserverconfig, :posix_expected => '/etc/puppetlabs/puppet/fileserver.conf', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/fileserver.conf'},
  {:name => :config, :posix_expected => '/etc/puppetlabs/puppet/puppet.conf', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/puppet.conf', :installed => :file},
  {:name => :route_file, :posix_expected => '/etc/puppetlabs/puppet/routes.yaml', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/routes.yaml'},
  {:name => :ssldir, :posix_expected => '/etc/puppetlabs/puppet/ssl', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/etc/ssl', :installed => :dir},

  # vardir
  {:name => :vardir, :posix_expected => '/opt/puppetlabs/puppet/cache', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache', :installed => :dir},
  {:name => :bucketdir, :posix_expected => '/opt/puppetlabs/puppet/cache/bucket', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/bucket'},
  {:name => :clientyamldir, :posix_expected => '/opt/puppetlabs/puppet/cache/client_yaml', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/client_yaml', :installed => :dir},
  {:name => :client_datadir, :posix_expected => '/opt/puppetlabs/puppet/cache/client_data', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/client_data', :installed => :dir},
  {:name => :clientbucketdir, :posix_expected => '/opt/puppetlabs/puppet/cache/clientbucket', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/clientbucket', :installed => :dir},
  {:name => :devicedir, :posix_expected => '/opt/puppetlabs/puppet/cache/devices', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/devices'},
  {:name => :pluginfactdest, :posix_expected => '/opt/puppetlabs/puppet/cache/facts.d', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/facts.d', :installed => :dir},
  {:name => :libdir, :posix_expected => '/opt/puppetlabs/puppet/cache/lib', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/lib', :installed => :dir},
  {:name => :factpath, :posix_expected => '/opt/puppetlabs/puppet/cache/lib/facter:/opt/puppetlabs/puppet/cache/facts', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/lib/facter;C:/ProgramData/PuppetLabs/puppet/cache/facts', :not_path => true},
  {:name => :module_working_dir, :posix_expected => '/opt/puppetlabs/puppet/cache/puppet-module', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/puppet-module'},
  {:name => :reportdir, :posix_expected => '/opt/puppetlabs/puppet/cache/reports', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/reports'},
  {:name => :server_datadir, :posix_expected => '/opt/puppetlabs/puppet/cache/server_data', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/server_data'},
  {:name => :statedir, :posix_expected => '/opt/puppetlabs/puppet/cache/state', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/state', :installed => :dir},
  {:name => :yamldir, :posix_expected => '/opt/puppetlabs/puppet/cache/yaml', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/cache/yaml'},

  # logdir/rundir
  {:name => :logdir, :posix_expected => '/var/log/puppetlabs', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/var/log', :installed => :dir},
  {:name => :rundir, :posix_expected => '/var/run/puppetlabs', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/var/run', :installed => :dir},
  {:name => :pidfile, :posix_expected => '/var/run/puppetlabs/agent.pid', :win_expected => 'C:/ProgramData/PuppetLabs/puppet/var/run/agent.pid'},
]

step 'test configprint outputs'
agents.each do |agent|
  config_options.each do |config_option|
    on(agent, puppet_agent('--configprint ' "#{config_option[:name]}")) do
      file = if agent['platform'] =~ /win/ then config_option[:win_expected] else config_option[:posix_expected] end
      assert_match(file, stdout)
    end
  end
end

step 'test puppet genconfig entries'
agents.each do |agent|
  on(agent, puppet_agent('--genconfig')) do
    config_options.each do |config_option|
      file = if agent['platform'] =~ /win/ then config_option[:win_expected] else config_option[:posix_expected] end
      assert_match("#{config_option[:name]} = #{file}", stdout)
    end
  end
end

step 'test puppet config paths exist'
agents.each do |agent|
  config_options.select {|v| !v[:not_path] }.each do |config_option|
    path = if agent['platform'] =~ /win/ then config_option[:win_expected] else config_option[:posix_expected] end
    case config_option[:installed]
    when :dir
      if !dir_exists?(agent, path)
        fail_test("Failed to find expected directory '#{path}' on agent '#{agent}'")
      end
    when :file
      if !file_exists?(agent, path)
        fail_test("Failed to find expected file '#{path}' on agent '#{agent}'")
      end
    end
  end
end


# mco.bat removed until it's added back to the MSI
public_binaries = {
  :posix => ['puppet', 'facter', 'hiera', 'mco', 'cfacter'],
  :win   => ['puppet.bat', 'facter.bat', 'hiera.bat', 'cfacter.bat']
}
locations = {:posix => {:aio => '/opt/puppetlabs/bin',                     :git => '/usr/bin'},
             :win   => {:aio => 'C:/Program Files/Puppet Labs/Puppet/bin', :git => '/usr/bin'}}

step 'test puppet binaries exist'
agents.each do |agent|
  os = agent['platform'] =~ /win/ ? :win : :posix
  type = @options[:type] == 'aio' ? :aio : :git

  dir = locations[os][type]
  # Filter out cfacter outside of aio, as we don't install it as part of Puppet acceptance runs yet.
  public_binaries[os].select {|v| type == :aio || v !~ /cfacter/}.each do |binary|
    path = File.join(dir, binary)
    case os
    when :win
      if !file_exists?(agent, path)
        fail_test("Failed to find expected binary '#{path}' on agent '#{agent}'")
      end
    when :posix
      if !link_exists?(agent, path)
        fail_test("Failed to find expected symbolic link '#{path}' on agent '#{agent}'")
      end
    end
  end
end

