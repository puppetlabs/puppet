test_name "dynamic environments"
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

step "setup environments"

stub_forge_on(master)

testdir = master.tmpdir("confdir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

results = {}
review = {}

####################
step "[ Run Tests ]"

existing_dynamic_scenario = "Test a specific, existing dynamic environment configuration"
step existing_dynamic_scenario
master_opts = {
  'main' => {
    'manifest' => '$confdir/dynamic/$environment/manifests',
    'modulepath' => '$confdir/dynamic/$environment/modules',
    'config_version' => '$confdir/static-version.sh',
  }
}
results[existing_dynamic_scenario] = use_an_environment("testing", "dynamic testing", master_opts, testdir)

default_environment_scenario = "Test behavior of default environment"
step default_environment_scenario
results[default_environment_scenario] = use_an_environment(nil, "default environment", master_opts, testdir)

non_existent_environment_scenario = "Test for an environment that does not exist"
step non_existent_environment_scenario
results[non_existent_environment_scenario] = use_an_environment("doesnotexist", "non existent environment", master_opts, testdir)

########################################
step "[ Report on Environment Results ]"

step "Reviewing: #{existing_dynamic_scenario}"
review[existing_dynamic_scenario] = review_results(results[existing_dynamic_scenario],
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*/tmp.*/dynamic/testing/manifests$},
                 %r{modulepath.*/tmp.*/dynamic/testing/modules$},
                 %r{config_version.*/tmp.*/static-version.sh$}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into /tmp.*/dynamic/testing/modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from /tmp.*/dynamic/testing/modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include dynamic testing environment testing_mod}],
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version 'static'},
                 %r{in dynamic testing environment site.pp},
                 %r{include dynamic testing environment testing_mod}],
  }
)

step "Reviewing: #{default_environment_scenario}"
default_expectations = lambda do |env|
  {
    :puppet_config => {
      :exit_code => 0,
      :matches => [%r{manifest.*/tmp.*/dynamic/#{env}/manifests$},
                   %r{modulepath.*/tmp.*/dynamic/#{env}/modules$},
                   %r{^config_version.*/tmp.*/static-version.sh$}]
    },
    :puppet_module_install => {
      :exit_code => 0,
      :matches => [%r{Preparing to install into /tmp.*/dynamic/#{env}/modules},
                   %r{pmtacceptance-nginx}],
    },
    :puppet_module_uninstall => {
      :exit_code => 0,
      :matches => [%r{Removed.*pmtacceptance-nginx.*from /tmp.*/dynamic/#{env}/modules}],
    },
    :puppet_apply => {
      :exit_code => 1,
      :matches => [ENV['PARSER'] == 'future' ?
                   %r{Error:.*Could not find class ::testing_mod} :
                   %r{Error:.*Could not find class testing_mod}
                  ],
    },
    :puppet_agent => {
      :exit_code => 0,
      :matches => [%r{Applying configuration version 'static'}],
      :does_not_match => [%r{in default environment site.pp},
                          %r{include default environment testing_mod},
                          %r{Notice: include}],
    },
  }
end
review[default_environment_scenario] = review_results(
  results[default_environment_scenario],
  default_expectations.call('production')
)

step "Reviewing: #{non_existent_environment_scenario}"
review[non_existent_environment_scenario] = review_results(
  results[non_existent_environment_scenario],
  default_expectations.call('doesnotexist')
)

#########################
step "[ Assert Success ]"

assert_review(review)
