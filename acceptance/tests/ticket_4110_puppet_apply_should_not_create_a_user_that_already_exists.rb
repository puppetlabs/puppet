test_name "#4110: puppet apply should not create a user that already exists"

apply_manifest_on(agents, "user { 'root': ensure => 'present' }") do
  fail_test("we tried to create root on this host") if stdout =~ /created/
end
