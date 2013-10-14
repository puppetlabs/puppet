test_name "Exercise loading a face from a module"

# Because the module tool does not work on windows, we can't run this test there
confine :except, :platform => 'windows'

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils
initialize_temp_dirs

agents.each do |agent|
  dev_modulepath = get_test_file_path(agent, 'dev/modules')
  user_modulepath = get_test_file_path(agent, 'user/modules')

  # make sure that we use the modulepath from the dev environment
  create_test_file(agent, 'puppet.conf', <<"END")
[user]
environment=dev
modulepath=#{user_modulepath}

[dev]
modulepath=#{dev_modulepath}
END
  puppetconf = get_test_file_path(agent, 'puppet.conf')

  on agent, 'rm -rf puppetlabs-helloworld'
  on agent, puppet("module", "generate", "puppetlabs-helloworld")
  mkdirs agent, 'puppetlabs-helloworld/lib/puppet/application'
  mkdirs agent, 'puppetlabs-helloworld/lib/puppet/face'

  # copy application, face, and utility module
  create_remote_file(agent, "puppetlabs-helloworld/lib/puppet/application/helloworld.rb", <<'EOM')
require 'puppet/face'
require 'puppet/application/face_base'

class Puppet::Application::Helloworld < Puppet::Application::FaceBase
end
EOM

  create_remote_file(agent, "puppetlabs-helloworld/lib/puppet/face/helloworld.rb", <<'EOM')
Puppet::Face.define(:helloworld, '0.0.1') do
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

  create_remote_file(agent, "puppetlabs-helloworld/lib/puppet/helloworld.rb", <<'EOM')
module Puppet::Helloworld
  def print
    puts "Hello world from a required module"
  end
  module_function :print
end
EOM

  on agent, puppet('module', 'build', 'puppetlabs-helloworld')
  # Why from 3.1.1 -> 3.2.0 did the version of this module change from 0.0.1
  # to 0.1.0 but the api within the face didn't?
  on agent, puppet('module', 'install', '--ignore-dependencies', '--target-dir', dev_modulepath, 'puppetlabs-helloworld/pkg/puppetlabs-helloworld-0.1.0.tar.gz')

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
