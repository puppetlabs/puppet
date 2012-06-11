test_name "Setup for hiera parser function"

apply_manifest_on master, <<-PP
file { '/etc/puppet/hiera.yaml':
  ensure  => present,
  content => '---
    :backends:
      - "yaml"
    :logger: "console"
    :hierarchy:
      - "%{fqdn}"
      - "%{environment}"
      - "global"

    :yaml:
      :datadir: "/var/lib/hiera"
  '
}

file { '/var/lib/hiera':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP

