# 2011-02-23
#
# AffectedVersion: 2.6.0-2.6.5
# FixedVersion:

test_name "#6418: file recursion and audit"

manifest = %q{
    file { "/tmp/6418": ensure => directory }
    file { "/tmp/6418/dir": ensure => directory}
    file { "/tmp/6418/dir/dir": ensure => directory}
    file { "/tmp/6418/dir/dir/dir": ensure => directory}
    file { "/tmp/6418-copy": ensure => present, source => "/tmp/6418/" }

    File["/tmp/6418"] -> File["/tmp/6418/dir"] -> File["/tmp/6418/dir/dir"] -> File["/tmp/6418/dir/dir/dir"] -> File["/tmp/6418-copy"]
}

step "Query agent for statefile"
agent=agents.first
on agent, puppet_agent('--configprint statefile')
statefile=stdout.chomp

step "Remove the statefile on all Agents"
on agents, "rm -f #{statefile}"

step "Apply the manifest"
apply_manifest_on agents, manifest


step "Verify corecct file recursion and audit state"
agents.each do |agent|
  on(agent, "grep ensure.*directory #{statefile}", :acceptable_exit_codes => [ 1 ])
end
