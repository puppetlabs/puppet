test_name "Test behavior of default environment"
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

codedir = master.puppet('master')['codedir']
testdir = create_tmpdir_for_user master, "codedir"
puppet_code_backup_dir = create_tmpdir_for_user(master, "puppet-code-backup-dir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

step  "Test"
master_opts = {
  'main' => {
    'environmentpath' => '$codedir/environments',
  }
}
general = [ master_opts, testdir, puppet_code_backup_dir, { :directory_environments => true } ]
env = 'production'

results = use_an_environment(nil, "default environment", *general)

expectations = {
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*#{codedir}/environments/#{env}/manifests$},
                 %r{modulepath.*#{codedir}/environments/#{env}/modules:.+},
                 %r{config_version = $}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{codedir}/environments/#{env}/modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{codedir}/environments/#{env}/modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include default environment testing_mod}],
    :notes => "The production directory environment is empty, but the inclusion of basemodulepath in the directory environment modulepath picks up the default testing_mod class in $codedir/modules"
  },
  :puppet_agent => {
    :exit_code => 0,
    :matches => [ %r{Applying configuration version '\d+'}],
    :does_not_match => [%r{include.*testing_mod},
                        %r{Warning.*404}],
    :notes => "The master automatically creates an empty production env dir."
  }
}

assert_review(review_results(results,expectations))
