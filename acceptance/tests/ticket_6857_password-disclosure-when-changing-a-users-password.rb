test_name "#6857: redact password hashes when applying in noop mode"

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

apply_manifest_on(agents, adduser_manifest )
results = apply_manifest_on(agents, changepass_manifest )

results.each do |result|
  assert_match( /current_value \[old password hash redacted\], should be \[new password hash redacted\]/ , "#{result.stdout}" )
end
