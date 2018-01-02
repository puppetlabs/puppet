test_name "#4233: resource with a newline"

# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
# AffectedVersion: 2.6.0rc3
# FixedVersion: 2.6.0

# JJM We expect 2.6.0rc3 to return an error
# and 2.6.0 final to not return an error line.
# Look for the line in the output and fail the test
# if we find it.

tag 'audit:low',      # basic parser functionality
    'audit:refactor', # Use block style `test_run`
    'audit:unit'

agents.each do |host|
  resource = host.echo('-e "\nHello World\n"')
  apply_manifest_on(host, "exec { '#{resource}': }") do
    assert_match(/Hello World.*success/, stdout) unless host['locale'] == 'ja'
  end
end
