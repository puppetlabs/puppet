test_name "legacy environments"
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

step "setup environments"

stub_forge_on(master)

testdir = create_tmpdir_for_user master, "confdir"
puppet_conf_backup_dir = create_tmpdir_for_user(master, "puppet-conf-backup-dir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

results = {}
review = {}

####################
step "[ Run Tests ]"

existing_legacy_scenario = "Test a specific, existing legacy environment configuration"
step existing_legacy_scenario
master_opts = {
  'testing' => {
    'manifest' => "$confdir/testing-manifests",
    'modulepath' => "$confdir/testing-modules",
    'config_version' => "$confdir/static-version.sh",
  },
}
results[existing_legacy_scenario] = use_an_environment("testing", "legacy testing", master_opts, testdir, puppet_conf_backup_dir)

default_environment_scenario = "Test behavior of default environment"
step default_environment_scenario
results[default_environment_scenario] = use_an_environment(nil, "default environment", master_opts, testdir, puppet_conf_backup_dir)

non_existent_environment_scenario = "Test for an environment that does not exist"
step non_existent_environment_scenario
results[non_existent_environment_scenario] = use_an_environment("doesnotexist", "non existent environment", master_opts, testdir, puppet_conf_backup_dir)

########################################
step "[ Report on Environment Results ]"

confdir = master.puppet['confdir']

step "Reviewing: #{existing_legacy_scenario}"
review[existing_legacy_scenario] = review_results(results[existing_legacy_scenario],
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*#{confdir}/testing-manifests$},
                 %r{modulepath.*#{confdir}/testing-modules$},
                 %r{config_version.*#{confdir}/static-version.sh$}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{confdir}/testing-modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{confdir}/testing-modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include legacy testing environment testing_mod}],
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version 'static'},
                 %r{in legacy testing environment site.pp},
                 %r{include legacy testing environment testing_mod}],
  }
)

step "Reviewing: #{default_environment_scenario}"
default_expectations = {
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*#{confdir}/manifests/site.pp$},
                 %r{modulepath.*#{confdir}/modules:.*},
                 %r{^config_version\s+=\s*$}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{confdir}/modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{confdir}/modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include default environment testing_mod}],
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version '\d+'},
                 %r{in default environment site.pp},
                 %r{include default environment testing_mod}],
  },
}
review[default_environment_scenario] = review_results(
  results[default_environment_scenario],
  default_expectations
)

step "Reviewing: #{non_existent_environment_scenario}"
review[non_existent_environment_scenario] = review_results(
  results[non_existent_environment_scenario],
  default_expectations
)

#########################
step "[ Assert Success ]"

assert_review(review)
