test_name "directory environments"
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

existing_directory_scenario = "Test a specific, existing directory environment configuration"
step existing_directory_scenario
master_opts = {
  'main' => {
    'environmentpath' => '$confdir/environments',
    'config_version' => '$confdir/static-version.sh',
  }
}
general = [ master_opts, testdir, puppet_conf_backup_dir, { :directory_environments => true } ]

results[existing_directory_scenario] = use_an_environment("testing", "directory testing", *general)

default_environment_scenario = "Test behavior of default environment"
step default_environment_scenario
results[default_environment_scenario] = use_an_environment(nil, "default environment", *general)

non_existent_environment_scenario = "Test for an environment that does not exist"
step non_existent_environment_scenario
results[non_existent_environment_scenario] = use_an_environment("doesnotexist", "non existent environment", *general)

with_explicit_environment_conf_scenario = "Test a specific, existing directory environment with an explicit environment.conf file"
step with_explicit_environment_conf_scenario
results[with_explicit_environment_conf_scenario] = use_an_environment("testing_environment_conf", "directory with environment.conf testing", *general)

master_environmentpath_scenario = "Test behavior of a directory environment when environmentpath is set in the master section"
step master_environmentpath_scenario
master_opts = {
  'master' => {
    'environmentpath' => '$confdir/environments',
    'config_version' => '$confdir/static-version.sh',
  }
}
results[master_environmentpath_scenario] = use_an_environment("testing", "master environmentpath", master_opts, testdir, puppet_conf_backup_dir, :directory_environments => true, :config_print => '--section=master')

bad_environmentpath_scenario = "Test behavior of directory environments when environmentpath is set to a non-existent directory"
step bad_environmentpath_scenario
master_opts = {
  'main' => {
    'environmentpath' => '/doesnotexist',
    'config_version' => '$confdir/static-version.sh',
  }
}
results[bad_environmentpath_scenario] = use_an_environment("testing", "bad environmentpath", master_opts, testdir, puppet_conf_backup_dir, :directory_environments => true)

########################################
step "[ Report on Environment Results ]"

step "Reviewing: #{existing_directory_scenario}"
existing_directory_expectations = lambda do |env|
  {
    :puppet_config => {
      :exit_code => 0,
      :matches => [%r{manifest.*#{master['puppetpath']}/environments/#{env}/manifests$},
                   %r{modulepath.*#{master['puppetpath']}/environments/#{env}/modules:.+},
                   %r{config_version = $}]
    },
    :puppet_module_install => {
      :exit_code => 0,
      :matches => [%r{Preparing to install into #{master['puppetpath']}/environments/#{env}/modules},
                   %r{pmtacceptance-nginx}],
    },
    :puppet_module_uninstall => {
      :exit_code => 0,
      :matches => [%r{Removed.*pmtacceptance-nginx.*from #{master['puppetpath']}/environments/#{env}/modules}],
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
end
review[existing_directory_scenario] = review_results(
  results[existing_directory_scenario],
  existing_directory_expectations.call('testing')
)

step "Reviewing: #{default_environment_scenario}"
default_environment_expectations = existing_directory_expectations.call('production').merge(
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include default environment testing_mod}],
    :notes => "The production directory environment is empty, but the inclusion of basemodulepath in the directory environment modulepath picks up the default testing_mod class in $confdir/modules"
  },
  :puppet_agent => {
    :exit_code => 0,
    :matches => [ %r{Applying configuration version '\d+'}],
    :does_not_match => [%r{include.*testing_mod},
                        %r{Warning.*404}],
    :notes => "The master automatically creates an empty production env dir."
  }
)
review[default_environment_scenario] = review_results(
  results[default_environment_scenario],
  default_environment_expectations
)

step "Reviewing: #{non_existent_environment_scenario}"
non_existent_environment_expectations = lambda do |env,path|
  {
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
end

review[non_existent_environment_scenario] = review_results(
  results[non_existent_environment_scenario],
  non_existent_environment_expectations.call('doesnotexist', master['puppetpath'])
)

existing_directory_with_puppet_conf_expectations = {
  :puppet_config => {
    :exit_code => 0,
    :matches => [%r{manifest.*#{master['puppetpath']}/environments/testing_environment_conf/nonstandard-manifests$},
                 %r{modulepath.*#{master['puppetpath']}/environments/testing_environment_conf/nonstandard-modules:.+},
                 %r{config_version = #{master['puppetpath']}/environments/testing_environment_conf/local-version.sh$}]
  },
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{master['puppetpath']}/environments/testing_environment_conf/nonstandard-modules},
                 %r{pmtacceptance-nginx}],
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{master['puppetpath']}/environments/testing_environment_conf/nonstandard-modules}],
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include directory testing with environment\.conf testing_mod}],
  },
  :puppet_agent => {
    :exit_code => 2,
    :matches => [%r{Applying configuration version 'local testing_environment_conf'},
                 %r{in directory testing with environment\.conf site.pp},
                 %r{include directory testing with environment\.conf testing_mod}],
  },
}
step "Reviewing: #{with_explicit_environment_conf_scenario}"
review[with_explicit_environment_conf_scenario] = review_results(
  results[with_explicit_environment_conf_scenario],
  existing_directory_with_puppet_conf_expectations
)

master_environmentpath_expectations = existing_directory_expectations.call('testing').merge(
  :puppet_module_install => {
    :exit_code => 0,
    :matches => [%r{Preparing to install into #{master['puppetpath']}/modules},
                 %r{pmtacceptance-nginx}],
    :expect_failure => true,
    :notes => "Runs in user mode and doesn't see the master environmenetpath setting.",
  },
  :puppet_module_uninstall => {
    :exit_code => 0,
    :matches => [%r{Removed.*pmtacceptance-nginx.*from #{master['puppetpath']}/modules}],
    :expect_failure => true,
    :notes => "Runs in user mode and doesn't see the master environmenetpath setting.",
  },
  :puppet_apply => {
    :exit_code => 0,
    :matches => [%r{include default environment testing_mod}],
    :expect_failure => true,
    :notes => "Runs in user mode and doesn't see the master environmenetpath setting.",
  }
)
step "Reviewing: #{master_environmentpath_scenario}"
review[master_environmentpath_scenario] = review_results(
  results[master_environmentpath_scenario],
  master_environmentpath_expectations
)

bad_environmentpath_expectations = non_existent_environment_expectations.call('testing', '/doesnotexist')
step "Reviewing: #{bad_environmentpath_scenario}"
review[bad_environmentpath_scenario] = review_results(
  results[bad_environmentpath_scenario],
  bad_environmentpath_expectations
)

#########################
step "[ Assert Success ]"

assert_review(review)
