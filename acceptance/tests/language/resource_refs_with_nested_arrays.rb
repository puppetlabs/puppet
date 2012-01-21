test_name "#7681: Allow using array variables in resource references"

test_manifest = <<MANIFEST
$exec_names = ["first", "second"]
exec { "first":
  command => "echo the first command",
  path => "/usr/bin:/bin",
  logoutput => true,
}
exec { "second":
  command => "echo the second command",
  path => "/usr/bin:/bin",
  logoutput => true,
}
exec { "third":
  command => "echo the final command",
  path => "/usr/bin:/bin",
  logoutput => true,
  require => Exec[$exec_names],
}
MANIFEST

results = apply_manifest_on agents, test_manifest

results.each do |result|
  assert_match(/Exec\[third\].*the final command/, "#{result.stdout}")
end
