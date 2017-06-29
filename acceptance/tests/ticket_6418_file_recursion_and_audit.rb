# 2011-02-23
#
# AffectedVersion: 2.6.0-2.6.5
# FixedVersion:

test_name "#6418: file recursion and audit"

tag 'audit:low',
    'audit:refactor',    # Use block style `test_name`
    'audit:integration'

agents.each do |agent|
  dir = agent.tmpdir('6418-recurse-audit')

manifest = %Q{
    file { "#{dir}/6418": ensure => directory }
    file { "#{dir}/6418/dir": ensure => directory}
    file { "#{dir}/6418/dir/dir": ensure => directory}
    file { "#{dir}/6418/dir/dir/dir": ensure => directory}
    file { "#{dir}/6418-copy": ensure => present, source => "#{dir}/6418/" }

    File["#{dir}/6418"] -> File["#{dir}/6418/dir"] -> File["#{dir}/6418/dir/dir"] -> File["#{dir}/6418/dir/dir/dir"] -> File["#{dir}/6418-copy"]
}

  step "Query agent for statefile"
  on agent, puppet_agent('--configprint statefile') do
    statefile=stdout.chomp

    step "Remove the statefile on the agent"
    on(agent, "rm -f '#{statefile}'")

    step "Apply the manifest"
    apply_manifest_on agent, manifest

    step "Verify correct file recursion and audit state"
    on(agent, "grep ensure.*directory '#{statefile}'", :acceptable_exit_codes => [ 1 ])
  end
end
