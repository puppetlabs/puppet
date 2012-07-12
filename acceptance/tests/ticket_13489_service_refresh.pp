test_name "#13489: refresh service"

confine :to, :platform => 'windows'

manifest = <<MANIFEST
service { 'BITS':
  ensure => 'running',
}

exec { 'hello':
  command => "cmd /c echo hello",
  path => $::path,
  logoutput => true,
}

Exec['hello'] ~> Service['BITS']
MANIFEST

step "Refresh service"
apply_manifest_on(agents, manifest)
