test_name "Test behavior of directory environments when environmentpath is set to a non-existent directory"
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils
require 'puppet/acceptance/classifier_utils'
extend Puppet::Acceptance::ClassifierUtils

classify_nodes_as_agent_specified_if_classifer_present

step "setup environments"

stub_forge_on(master)

testdir = create_tmpdir_for_user master, "confdir"
puppet_conf_backup_dir = create_tmpdir_for_user(master, "puppet-conf-backup-dir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

step  "Test"
master_opts = {
  'main' => {
    'environmentpath' => '/doesnotexist',
  }
}
general = [ master_opts, testdir, puppet_conf_backup_dir, { :directory_environments => true } ]
env = 'doesnotexist'
path = master.puppet('master')['codedir']

results = use_an_environment("testing", "bad environmentpath", master_opts, testdir, puppet_conf_backup_dir, :directory_environments => true)

expectations = {
  :puppet_config => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{path}}],
  },
  :puppet_module_install => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{path}}],
  },
  :puppet_module_uninstall => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{path}}],
  },
  :puppet_apply => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{path}}],
  },
  :puppet_agent => {
    :exit_code => 1,
    :matches => [%r{Warning.*404.*Could not find environment '#{env}'},
                 %r{Could not retrieve catalog; skipping run}],
  },
}

review_results(results,expectations)
