test_name "#6857: redact password hashes when applying in noop mode"

hosts_to_test = agents.reject do |agent|
  if agent['platform'].match /(?:ubuntu|centos|debian|el-|fc-)/
    result = on(agent, %Q{#{agent['puppetbindir']}/ruby -e 'require "shadow" or raise'}, :silent => true)
    result.exit_code != 0
  else
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
