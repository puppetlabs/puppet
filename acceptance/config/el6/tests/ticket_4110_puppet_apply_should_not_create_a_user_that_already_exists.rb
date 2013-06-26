test_name "#4110: puppet apply should not create a user that already exists"

agents.each do |host|
  user = host['user']
  apply_manifest_on(host, "user { '#{user}': ensure => 'present' }") do
    assert_no_match(/created/, stdout, "we tried to create #{user} on #{host}")
  end
end
