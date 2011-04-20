test_name "#4233: resource with a newline"

# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
# AffectedVersion: 2.6.0rc3
# FixedVersion: 2.6.0

# JJM We expect 2.6.0rc3 to return an error
# and 2.6.0 final to not return an error line.
# Look for the line in the output and fail the test
# if we find it.
apply_manifest_on(agents, 'exec { \'/bin/echo -e "\nHello World\n"\': }') do
  stdout =~ /err:/ and fail_test("error report in output, sorry")
end
