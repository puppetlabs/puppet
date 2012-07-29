test_name "#11860: exec resources should not override system locale"

#######################################################################################
#                                   NOTE
#######################################################################################
#
# This test won't run properly until the test agent nodes have the Spanish language
# pack installed on them.  On an ubuntu system, this can be done with the following:
#
#  apt-get install language-pack-es-base
#
# Also, this test depends on the following pull requests:
#
#  https://github.com/puppetlabs/puppet-acceptance/pull/123
#  https://github.com/puppetlabs/facter/pull/159
#
#######################################################################################

temp_file_name = "/tmp/11860_exec_should_not_override_locale.txt"
locale_string = "es_ES.UTF-8"


step "Check value of LANG environment variable"

# in this step we are going to run an "exec" block that writes the value of the LANG
#  environment variable to a file.  We need to verify that exec's are no longer
#  forcefully setting this var to 'C'.


test_LANG_manifest = <<HERE
exec {"es_ES locale print LANG environment variable":
      command =>  "/usr/bin/printenv LANG > #{temp_file_name}",
}
HERE

# apply the manifest.
#
# note that we are passing in an extra :environment argument, which will cause the
# framework to temporarily set this variable before executing the puppet command.
# this lets us know what value we should be looking for as the output of the exec.

apply_manifest_on agents, test_LANG_manifest, :environment => {:LANG => locale_string}

# cat the temp file and make sure it contained the correct value.
on(agents, "cat #{temp_file_name}").each do |result|
  assert_equal(locale_string, "#{result.stdout.chomp}", "Unexpected result for host '#{result.host}'")
end



step "Check for locale-specific output of cat command"

# in this step we are going to run an "exec" block that runs the "cat" command.  The command
# is intentionally invalid, because we are going to run it using a non-standard locale and
# we want to confirm that the error message is in the correct language.

test_cat_manifest = <<HERE
exec {"es_ES locale invalid cat command":
      command =>  "/bin/cat SOME_FILE_THAT_DOESNT_EXIST > #{temp_file_name} 2>&1",
      returns => 1,
}
HERE

# apply the manifest, again passing in the extra :environment argument to set our locale.
apply_manifest_on agents, test_cat_manifest, :environment => {:LANG => locale_string}

# cat the output file and ensure that the error message is in spanish
on(agents, "cat #{temp_file_name}").each do |result|
  assert_equal("/bin/cat: SOME_FILE_THAT_DOESNT_EXIST: No existe el fichero o el directorio",
               "#{result.stdout.chomp}", "Unexpected result for host '#{result.host}'")
end


step "cleanup"

# remove the temp file
on agents, "rm -f #{temp_file_name}"



