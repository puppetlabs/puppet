test_name "#5224: exec resources should unset user-related environment variables"

#######################################################################################
#                                   NOTE
#######################################################################################
#
# This test depends on the following pull requests:
#
#  https://github.com/puppetlabs/puppet-acceptance/pull/123
#
# because it needs to be able to set some environment variables for the duration of
# the puppet commands.  Shouldn't be moved out of 'pending' until after that has been
# merged.
#
#######################################################################################


temp_file_name = "/tmp/5224_exec_should_unset_user_env_vars.txt"
sentinel_string = "Abracadabra"


# these should match up with the value of Puppet::Util::POSIX_USER_ENV_VARS,
# but I don't have access to that from here, so this is unfortunately hard-coded
# (cprice 2012-01-27)
POSIX_USER_ENV_VARS = ['HOME', 'USER', 'LOGNAME']



step "Check value of user-related environment variables"

# in this step we are going to run some "exec" blocks that writes the value of the
# user-related environment variables to a file.  We need to verify that exec's are
# unsetting these vars.


test_printenv_manifest = <<HERE
exec {"print %s environment variable":
      command =>  "/usr/bin/printenv %s > #{temp_file_name}",
}
HERE

# loop over the vars that we care about; these should match up with the value of Puppet::Util::POSIX_USER_ENV_VARS,
# but I don't have access to that from here, so this is unfortunately hard-coded (cprice 2012-01-27)
POSIX_USER_ENV_VARS.each do |var|

  # apply the manifest.
  #
  # note that we are passing in an extra :environment argument, which will cause the
  # framework to temporarily set this variable before executing the puppet command.
  # this lets us know what value we should be looking for as the output of the exec.

  apply_manifest_on agents, test_printenv_manifest % [var, var], :environment => {var => sentinel_string}

  # cat the temp file and make sure it contained the correct value.
  on(agents, "cat #{temp_file_name}").each do |result|
    assert_equal("", "#{result.stdout.chomp}", "Unexpected result for host '#{result.host}', environment var '#{var}'")
  end
end




step "Check value of user-related environment variables when they are provided as part of the exec resource"

# in this step we are going to run some "exec" blocks that write the value of the
# user-related environment variables to a file.  However, this time, the manifest
# explicitly overrides these variables in the "environment" section, so we need to
# be sure that we are respecting these overrides.

test_printenv_with_env_overrides_manifest = <<HERE
exec {"print %s environment variable":
      command =>  "/usr/bin/printenv %s > #{temp_file_name}",
      environment => ["%s=#{sentinel_string}", "FOO=bar"]
}
HERE

# loop over the vars that we care about;
POSIX_USER_ENV_VARS.each do |var|

  # apply the manifest.
  #
  # note that we are passing in an extra :environment argument, which will cause the
  # framework to temporarily set this variable before executing the puppet command.
  # this lets us know what value we should be looking for as the output of the exec.

  apply_manifest_on agents, test_printenv_with_env_overrides_manifest % [var, var, var],
                    :environment => {var => sentinel_string}

  # cat the temp file and make sure it contained the correct value.
  on(agents, "cat #{temp_file_name}").each do |result|
    assert_equal(sentinel_string, "#{result.stdout.chomp}",
                 "Unexpected result for host '#{result.host}', environment var '#{var}'")
  end
end








step "cleanup"

# remove the temp file
on agents, "rm -f #{temp_file_name}"



