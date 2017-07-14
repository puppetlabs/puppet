test_name "#6710: Relationship syntax should work with title arrays"

tag 'audit:low',
    'audit:refactor', # Use block style `test_name`
    'audit:unit'     # basic language syntax

# Jeff McCune <jeff@puppetlabs.com>
# 2011-03-14
#
# If bug 6710 is closed, then this manifests should apply cleanly.
# There should be a many-to-many relationship established.
#

apply_manifest_on agents, %q{
  notify { [ left_one, left_two ]: } -> notify { [ right_one, right_two ]: }
  notify { left: } -> notify { right: }
  notify { left_one_to_many: } -> notify { [ right_one_to_many_1, right_one_to_many_2 ]: }
}

