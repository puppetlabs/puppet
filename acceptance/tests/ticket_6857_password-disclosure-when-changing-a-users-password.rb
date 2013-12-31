test_name "#6857: redact password hashes when applying in noop mode"

hosts_to_test = agents.reject do |agent|
  result = on(agent, %Q{#{agent['puppetbindir']}/ruby -e 'require "shadow" or raise'}, :silent => true)
  result.exit_code != 0
end
skip_test "No suitable hosts found.  Without the Ruby shadow library, passwords cannot be set." if hosts_to_test.empty?

adduser_manifest = <<MANIFEST
user { 'passwordtestuser':
  ensure   => 'present',
  password => 'apassword',
}
MANIFEST

changepass_manifest = <<MANIFEST
user { 'passwordtestuser':
  ensure   => 'present',
  password => 'newpassword',
  noop     => true,
}
MANIFEST

apply_manifest_on(hosts_to_test, adduser_manifest )
results = apply_manifest_on(hosts_to_test, changepass_manifest )

results.each do |result|
  assert_match( /current_value \[old password hash redacted\], should be \[new password hash redacted\]/ , "#{result.host}: #{result.stdout}" )
end
