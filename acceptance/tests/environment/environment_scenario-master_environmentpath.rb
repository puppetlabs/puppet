test_name "Test behavior of a directory environment when environmentpath is set in the master section"
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
  'master' => {
    'environmentpath' => "#{testdir}/environments",
  }
}
env = 'testing'

results = use_an_environment(env, "master environmentpath", master_opts, testdir, puppet_code_backup_dir, :directory_environments => true)

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
    :notes => "Runs in user mode and doesn't see the master environmentpath setting.",
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{codedir}/environments/#{env}/modules}],
    :notes => "Runs in user mode and doesn't see the master environmentpath setting.",
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include directory #{env} environment testing_mod}],
    :notes => "Runs in user mode and doesn't see the master environmentpath setting.",
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version '\d+'},
                 %r{in directory #{env} environment site.pp},
                 %r{include directory #{env} environment testing_mod}],
  },
}

assert_review(review_results(results,expectations))
