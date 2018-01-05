test_name "Exercise loading a face from a module"

# Because the module tool does not work on windows, we can't run this test there
confine :except, :platform => 'windows'
confine :except, :platform => /centos-4|el-4/ # PUP-5226

tag 'audit:medium',
    'audit:acceptance',    # This has been OS sensitive.
    'audit:refactor'       # Remove the confine against windows and refactor to
                           # accommodate the Windows platform.

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils
initialize_temp_dirs

agents.each do |agent|
    
  if on(agent, facter("fips_enabled")).stdout =~ /true/
    puts "Module build, loading and installing not supported on fips enabled platforms"
    next
  end

  environmentpath = get_test_file_path(agent, 'environments')
  dev_modulepath = "#{environmentpath}/dev/modules"

  # make sure that we use the modulepath from the dev environment
  puppetconf = get_test_file_path(agent, 'puppet.conf')
  on agent, puppet("config", "set", "environmentpath", environmentpath, "--section", "main", "--config", puppetconf)
  on agent, puppet("config", "set", "environment", "dev", "--section", "user", "--config", puppetconf)

  on agent, 'rm -rf helloworld'
  on agent, puppet("module", "generate", "puppetlabs-helloworld", "--skip-interview")
  mkdirs agent, 'helloworld/lib/puppet/application'
  mkdirs agent, 'helloworld/lib/puppet/face'

  # copy application, face, and utility module
  create_remote_file(agent, "helloworld/lib/puppet/application/helloworld.rb", <<'EOM')
require 'puppet/face'
require 'puppet/application/face_base'

class Puppet::Application::Helloworld < Puppet::Application::FaceBase
end
EOM

  create_remote_file(agent, "helloworld/lib/puppet/face/helloworld.rb", <<'EOM')
Puppet::Face.define(:helloworld, '0.1.0') do
  summary "Hello world face"
  description "This is the hello world face"

  action 'actionprint' do
    summary "Prints hello world from an action"
    when_invoked do |options|
      puts "Hello world from an action"
    end
  end

  action 'moduleprint' do
    summary "Prints hello world from a required module"
    when_invoked do |options|
      require 'puppet/helloworld.rb'
      Puppet::Helloworld.print
    end
  end
end
EOM

  create_remote_file(agent, "helloworld/lib/puppet/helloworld.rb", <<'EOM')
module Puppet::Helloworld
  def print
    puts "Hello world from a required module"
  end
  module_function :print
end
EOM

  on agent, puppet('module', 'build', 'helloworld')
  on agent, puppet('module', 'install', '--ignore-dependencies', '--target-dir', dev_modulepath, 'helloworld/pkg/puppetlabs-helloworld-0.1.0.tar.gz')

  on(agent, puppet('help', '--config', puppetconf)) do
    assert_match(/helloworld\s*Hello world face/, stdout, "Face missing from list of available subcommands")
  end

  on(agent, puppet('help', 'helloworld', '--config', puppetconf)) do
    assert_match(/This is the hello world face/, stdout, "Descripion help missing")
    assert_match(/moduleprint\s*Prints hello world from a required module/, stdout, "help for moduleprint action missing")
    assert_match(/actionprint\s*Prints hello world from an action/, stdout, "help for actionprint action missing")
  end

  on(agent, puppet('helloworld', 'actionprint', '--config', puppetconf)) do
    assert_match(/^Hello world from an action$/, stdout, "face did not print hello world")
  end

  on(agent, puppet('helloworld', 'moduleprint', '--config', puppetconf)) do
    assert_match(/^Hello world from a required module$/, stdout, "face did not load module to print hello world")
  end
end
