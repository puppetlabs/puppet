test_name "#4110: puppet apply should not create a user that already exists"

agents.each do |host|
  apply_manifest_on(host, "user { 'root': ensure => 'present' }") do
     assert_no_match(/created/, stdout, "we tried to create root on #{host}" )
  end
end
