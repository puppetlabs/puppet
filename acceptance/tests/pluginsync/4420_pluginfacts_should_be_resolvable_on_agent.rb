test_name "Pluginsync'ed external facts should be resolvable on the agent" do
  confine :except, :platform => 'cisco_nexus' #See BKR-749

  tag 'audit:medium',
      'audit:integration'

#
# This test is intended to ensure that external facts downloaded onto an agent via
# pluginsync are resolvable. In Linux, the external fact should have the same
# permissions as its source on the master.
#

  step "Create a codedir with a manifest and test module with external fact"
  codedir = master.tmpdir('4420-codedir')

  site_manifest_content = <<EOM
node default {
  include mymodule
  notify { "foo is ${foo}": }
}
EOM

  unix_fact = <<EOM
#!/bin/sh
echo "foo=bar"
EOM

  win_fact = <<EOM
@echo off
echo foo=bar
EOM

  apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  mode   => "0755",
  owner  => #{master.puppet['user']},
  group  => #{master.puppet['group']},
}

file {
  '#{codedir}':;
  '#{codedir}/environments':;
  '#{codedir}/environments/production':;
  '#{codedir}/environments/production/manifests':;
  '#{codedir}/environments/production/modules':;
  '#{codedir}/environments/production/modules/mymodule':;
  '#{codedir}/environments/production/modules/mymodule/manifests':;
  '#{codedir}/environments/production/modules/mymodule/facts.d':;
}

file { '#{codedir}/environments/production/manifests/site.pp':
  ensure => file,
  content => '#{site_manifest_content}',
}

file { '#{codedir}/environments/production/modules/mymodule/manifests/init.pp':
  ensure => file,
  content => 'class mymodule {}',
}

file { '#{codedir}/environments/production/modules/mymodule/facts.d/unix_external_fact.sh':
  ensure  => file,
  mode    => '755',
  content => '#{unix_fact}',
}
file { '#{codedir}/environments/production/modules/mymodule/facts.d/win_external_fact.bat':
  ensure  => file,
  mode    => '644',
  content => '#{win_fact}',
}
MANIFEST

  master_opts = {
      'main' => {
          'environmentpath' => "#{codedir}/environments"
      }
  }

  with_puppet_running_on(master, master_opts, codedir) do
    agents.each do |agent|
      factsd         = agent.tmpdir('facts.d')
      pluginfactdest = agent.tmpdir('facts.d')
      tmpdir         = agent.tmpdir('tmpdir')
      testfile       = File.join(tmpdir, 'testfile')

      teardown do
        on(master, "rm -rf '#{codedir}'")
        on(agent, "rm -rf '#{factsd}' '#{pluginfactdest}'")
      end

      step "Pluginsync the external fact to the agent and ensure it resolves correctly" do
        on(agent, puppet('agent', '-t', '--server', master, '--pluginfactdest', factsd), :acceptable_exit_codes => [2]) do |result|
          assert_match(/foo is bar/, result.stdout)
        end
      end
      step "Use plugin face to download to the agent" do
        on(agent, puppet('plugin', 'download', '--server', master, '--pluginfactdest', pluginfactdest)) do |result|
          assert_match(/Downloaded these plugins: .*external_fact/, result.stdout) unless agent['locale'] == 'ja'
        end
      end

      step "Ensure it resolves correctly" do
        on(agent, puppet('apply', '--pluginfactdest', pluginfactdest, '-e', "'notify { \"foo is ${foo}\": }'")) do |result|
          assert_match(/foo is bar/, result.stdout)
        end
      end
      # Linux specific tests
      next if agent['platform'] =~ /windows/

      step "In Linux, ensure the pluginsync'ed external fact has the same permissions as its source" do
        on(agent, puppet('resource', "file '#{factsd}/unix_external_fact.sh'")) do |result|
          assert_match(/0755/, result.stdout)
        end
      end
      step "In Linux, ensure puppet apply uses the correct permissions" do
        test_source = File.join('/', 'tmp', 'test')
        on(agent, puppet('apply', "-e \"file { '#{test_source}': ensure => file, mode => '0456' }\""))

        { 'source_permissions => use,'    => /0456/,
          'source_permissions => ignore,' => /0644/,
          ''                              => /0644/
        }.each do |source_permissions, mode|
          on(agent, puppet('apply', "-e \"file { '/tmp/test_target': ensure => file, #{source_permissions} source => '#{test_source}' }\""))
          on(agent, puppet('resource', "file /tmp/test_target")) do |result|
            assert_match(mode, result.stdout)
          end

          on(agent, "rm -f /tmp/test_target")
        end
      end
    end
  end
end