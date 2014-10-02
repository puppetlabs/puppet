test_name "Agent should use environment given by ENC for fetching remote files"

testdir = create_tmpdir_for_user master, 'respect_enc_test'

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['puppetbindir']}/ruby
puts <<YAML
parameters:
environment: special
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => "0770",
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
  }
  file {
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/special/':;
    '#{testdir}/environments/special/manifests':;
    '#{testdir}/environments/special/modules':;
    '#{testdir}/environments/special/modules/amod':;
    '#{testdir}/environments/special/modules/amod/files':;
  }
  file { '#{testdir}/environments/special/modules/amod/files/testy':
    ensure => file,
    mode => "0640",
    content => 'special_environment',
  }
MANIFEST

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
    'environment_timeout' => 0,
  },
  'master' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb",
  },
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    atmp = agent.tmpdir('respect_enc_test')
    logger.debug "agent: #{agent} \tagent.tmpdir => #{atmp}"

    create_remote_file master, "#{testdir}/environments/special/manifests/different.pp", <<END
file { "#{atmp}/special_testy":
  source => "puppet:///modules/amod/testy",
}

notify { "mytemp is ${::mytemp}": }
END
    on master, "chmod 644 #{testdir}/environments/special/manifests/different.pp"

    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --trace")

    on agent, "cat #{atmp}/special_testy" do |result|
      assert_match(/special_environment/,
                   result.stdout,
                   "The file from environment 'special' was not found")
    end

    on agent, "rm -rf #{atmp}"
  end
end
