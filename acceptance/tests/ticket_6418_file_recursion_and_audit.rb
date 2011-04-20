# 2011-02-23
#
# AffectedVersion: 2.6.0-2.6.5
# FixedVersion:
#

test_name "#6418: file recursion and audit"

on agents, "rm -f /var/lib/puppet/state/state.yaml "
manifest = %q{
    file { "/tmp/6418": ensure => directory }
    file { "/tmp/6418/dir": ensure => directory}
    file { "/tmp/6418/dir/dir": ensure => directory}
    file { "/tmp/6418/dir/dir/dir": ensure => directory}
    file { "/tmp/6418-copy": ensure => present, source => "/tmp/6418/" }

    File["/tmp/6418"] -> File["/tmp/6418/dir"] -> File["/tmp/6418/dir/dir"] -> File["/tmp/6418/dir/dir/dir"] -> File["/tmp/6418-copy"]
}

step "Apply the manifest"
apply_manifest_on agents, manifest
on agents, "! grep ensure.*directory /var/lib/puppet/state/state.yaml"
