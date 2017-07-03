test_name "Test a specific, existing directory environment configuration"
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

env = 'testing'

results = use_an_environment(env, "directory testing", *general)
expectations = {
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*#{testdir}/environments/#{env}/manifests$},
                 %r{modulepath.*#{testdir}/environments/#{env}/modules:.+},
                 %r{config_version = $}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{testdir}/environments/#{env}/modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{testdir}/environments/#{env}/modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include directory #{env} environment testing_mod}],
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version '\d+'},
                 %r{in directory #{env} environment site.pp},
                 %r{include directory #{env} environment testing_mod}],
  },
}

assert_review(review_results(results, expectations))
