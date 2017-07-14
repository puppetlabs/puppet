# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-29
#
# AffectedVersion: <= 2.6.0rc1
# FixedVersion:
#
# This specification makes sure the syntax:
# Stage[main] -> Stage[last]
# works as expected

tag 'audit:high', # basic language functionality
    'audit:unit',
    'audit:refactor', # Use block style `test_name`
    'audit:delete'

apply_manifest_on agents, %q{
  stage { [ "pre", "post" ]: }
  Stage["pre"] -> Stage["main"] -> Stage["post"]
  class one   { notify { "class one, first stage":   } }
  class two   { notify { "class two, second stage":  } }
  class three { notify { "class three, third stage": } }
  class { "one": stage => pre }
  class { "two": }
  class { "three": stage => post }
}

