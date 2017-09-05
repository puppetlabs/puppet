test_name 'Ensure that agent receives proper error message when environment is inaccessible'
require 'puppet/acceptance/classifier_utils'
extend Puppet::Acceptance::ClassifierUtils

tag 'server'

classify_nodes_as_agent_specified_if_classifer_present

testdir = create_tmpdir_for_user master, 'env-with-access-problem'

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
  mode => "0770",
}

file {
  "#{testdir}":;
  "#{testdir}/environments":;
  "#{testdir}/environments/direnv":
    owner => 'root',
    group => 'root',
    mode => "0700"
}
MANIFEST

master_opts = {
  'master' => {
    'environmentpath' => "#{testdir}/environments",
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent,
       puppet("agent", "-t", "--server", master, "--environment", "direnv"),
       :acceptable_exit_codes => [1]) do |result|

      assert_match(/Permission denied - .*\/environments\/direnv/, result.stderr)
    end
  end
end
