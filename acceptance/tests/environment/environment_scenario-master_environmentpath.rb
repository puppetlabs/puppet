test_name "Test behavior of a directory environment when environmentpath is set in the master section"
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils
require 'puppet/acceptance/classifier_utils'
extend Puppet::Acceptance::ClassifierUtils

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
    'environmentpath' => '$codedir/environments',
  }
}
env = 'testing'

results = use_an_environment("testing", "master environmentpath", master_opts, testdir, puppet_code_backup_dir, :directory_environments => true, :config_print => '--section=master')

expectations = {
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*#{codedir}/environments/#{env}/manifests$},
                 %r{modulepath.*#{codedir}/environments/#{env}/modules:.+},
                 %r{config_version = $}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{codedir}/modules},
                 %r{pmtacceptance-nginx}],
    :expect_failure => true,
    :notes => "Runs in user mode and doesn't see the master environmenetpath setting.",
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{codedir}/modules}],
    :expect_failure => true,
    :notes => "Runs in user mode and doesn't see the master environmenetpath setting.",
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include default environment testing_mod}],
    :expect_failure => true,
    :notes => "Runs in user mode and doesn't see the master environmenetpath setting.",
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version '\d+'},
                 %r{in directory #{env} environment site.pp},
                 %r{include directory #{env} environment testing_mod}],
  },
}

review_results(results,expectations)
