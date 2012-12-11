test_name "Exercise loading a face from a module"

agents.each do |agent|
  testdir = agent.tmpdir('face_helloworld')
  puppetconf = "#{testdir}/puppet.conf"
  basedir = "#{testdir}/dev/modules/helloworld/lib/puppet"

  on(agent, "mkdir -p #{basedir}/{application,face}")

  # make sure that we use the modulepath from the dev environment
  create_remote_file(agent, puppetconf, <<END)
[user]
environment=dev
modulepath=#{testdir}/user/modules

[dev]
modulepath=#{testdir}/dev/modules
END

  # copy application, face, and utility module
  create_remote_file(agent, "#{basedir}/application/helloworld.rb", <<EOM)
require 'puppet/face'
require 'puppet/application/face_base'

class Puppet::Application::Helloworld < Puppet::Application::FaceBase
end
EOM

  create_remote_file(agent, "#{basedir}/face/helloworld.rb", <<EOM)
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

  create_remote_file(agent, "#{basedir}/helloworld.rb", <<EOM)
module Puppet::Helloworld
  def print
    puts "Hello world from a required module"
  end
  module_function :print
end
EOM

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
