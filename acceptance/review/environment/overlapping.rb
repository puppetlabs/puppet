test_name "overlapping environments"
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

step "setup environments"

stub_forge_on(master)

testdir = master.tmpdir("confdir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)
apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
file { "#{testdir}/environments/testing/manifests/site.pp":
  ensure => file,
  content => '
    notify { "in environments/testing/manifests/site.pp": }
    include testing_mod
    include service_mod
  '
}
MANIFEST

results = {}
review = {}

####################
step "[ Run Tests ]"

overlapping_environment_scenario = "Testing overlapping environment configuration"
step overlapping_environment_scenario
master_opts = {
  'main' => {
    'basemodulepath' => '$confdir/services/$environment/modules',
    'environmentpath' => '$confdir/environments',
    'manifest' => '$confdir/environments/$environment/manifests',
    'modulepath' => '$confdir/environments/$environment/modules:$confdir/services/$environment/modules',
    'config_version' => '$confdir/static-version.sh',
  },
  'testing' => {
    'manifest' => "$confdir/testing-manifests",
    'modulepath' => "$confdir/testing-modules",
    'config_version' => "$confdir/static-version.sh",
  },
}
results[overlapping_environment_scenario] = use_an_environment("testing", "overlapping", master_opts, testdir)

default_environment_scenario = "Test behavior of default environment"
step default_environment_scenario
results[default_environment_scenario] = use_an_environment(nil, "default environment", master_opts, testdir)

non_existent_environment_scenario = "Test for an environment that does not exist"
step non_existent_environment_scenario
results[non_existent_environment_scenario] = use_an_environment("doesnotexist", "non existent environment", master_opts, testdir)

########################################
step "[ Report on Environment Results ]"

step "Reviewing: #{overlapping_environment_scenario}"
directory_environment_exists_expectations = {
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*/tmp.*/environments/testing/manifests$},
                 %r{modulepath.*/tmp.*/environments/testing/modules:.+},
                 %r{basemodulepath.*/tmp.*/services/testing/modules},
                 %r{config_version.*/tmp.*/static-version.sh$}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into /tmp.*/environments/testing/modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from /tmp.*/environments/testing/modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include directory testing environment testing_mod}],
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version 'static'},
                 %r{in directory testing environment site.pp},
                 %r{include directory testing environment testing_mod}],
  },
}
review[overlapping_environment_scenario] = review_results(
  results[overlapping_environment_scenario],
  directory_environment_exists_expectations
)

step "Reviewing: #{default_environment_scenario}"
default_expectations = lambda do |env|
  {
    :puppet_config => {
      :exit_code => 0,
      :matches => [%r{manifest.*/tmp.*/environments/#{env}/manifests$},
                   %r{modulepath.*/tmp.*/environments/#{env}/modules:.+},
                   %r{basemodulepath.*/tmp.*/services/#{env}/modules$},
                   %r{^config_version.*/tmp.*/static-version.sh$}]
    },
    :puppet_module_install => {
      :exit_code => 0,
      :matches => [%r{Preparing to install into /tmp.*/environments/#{env}/modules},
                   %r{pmtacceptance-nginx}],
    },
    :puppet_module_uninstall => {
      :exit_code => 0,
      :matches => [%r{Removed.*pmtacceptance-nginx.*from /tmp.*/environments/#{env}/modules}],
    },
    :puppet_apply => {
      :exit_code => 1,
      :matches => [%r{Error: Could not find class testing_mod}],
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
