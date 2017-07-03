test_name "Test for an environment that does not exist"
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils
require 'puppet/acceptance/classifier_utils'
extend Puppet::Acceptance::ClassifierUtils

tag 'audit:high',
    'audit:refactor',
    'audit:delete'  # These validations are covered by other tests.

classify_nodes_as_agent_specified_if_classifer_present

step "setup environments"

stub_forge_on(master)

testdir = create_tmpdir_for_user(master, File.basename(__FILE__))
puppet_code_backup_dir = create_tmpdir_for_user(master, "puppet-code-backup-dir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

step "Test"
master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  }
}
general = [ master_opts, testdir, puppet_code_backup_dir, { :directory_environments => true } ]
env = 'doesnotexist'

results = use_an_environment(env, "non existent environment", *general)

expectations = {
  :puppet_config => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{testdir}}],
  },
  :puppet_module_install => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{testdir}}],
  },
  :puppet_module_uninstall => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{testdir}}],
  },
  :puppet_apply => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{testdir}}],
  },
  :puppet_agent => {
    :exit_code => 1,
    :matches => [%r{(Warning|Error).*(404|400).*Could not find environment '#{env}'},
                 %r{Could not retrieve catalog; skipping run}],
  }
}

assert_review(review_results(results,expectations))
