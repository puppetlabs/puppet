test_name "#6857: redact password hashes when applying in noop mode"

hosts_to_test = agents.reject do |agent|
  if agent['platform'].match /(?:ubuntu|centos|debian|el-|fedora)/
    result = on(agent, %Q{#{agent['puppetbindir']}/ruby -e 'require "shadow" or raise'}, :acceptable_exit_codes => [0,1])
    result.exit_code != 0
  else
    # Non-linux platforms do not rely on ruby-libshadow for password management
    # and so we don't reject them from testing
    false
  end
end
skip_test "No suitable hosts found" if hosts_to_test.empty?

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
