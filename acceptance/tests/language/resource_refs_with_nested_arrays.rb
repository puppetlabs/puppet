test_name "#7681: Allow using array variables in resource references"

tag 'audit:high',
    'audit:unit'

agents.each do |agent|
  test_manifest = <<MANIFEST
$exec_names = ["first", "second"]
exec { "first":
  command => "#{agent.echo('the first command')}",
  path => "#{agent.path}",
  logoutput => true,
}
exec { "second":
  command => "#{agent.echo('the second command')}",
  path => "#{agent.path}",
  logoutput => true,
}
exec { "third":
  command => "#{agent.echo('the final command')}",
  path => "#{agent.path}",
  logoutput => true,
  require => Exec[$exec_names],
}
MANIFEST

  apply_manifest_on agent, test_manifest do
    assert_match(/Exec\[third\].*the final command/, stdout)
  end
end
