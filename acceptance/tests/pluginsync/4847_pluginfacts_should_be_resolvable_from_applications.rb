test_name "Pluginsync'ed custom facts should be resolvable during application runs"

tag 'audit:medium',
    'audit:integration',
    'server'

#
# This test is intended to ensure that custom facts downloaded onto an agent via
# pluginsync are resolvable by puppet applications besides agent/apply.
#

agents.each do |agent|
  step "Create a codedir with a test module with external fact"
  codedir = agent.tmpdir('4847-codedir')
  on agent, "mkdir -p #{codedir}/facts"
  on agent, "mkdir -p #{codedir}/lib/facter"
  on agent, "mkdir -p #{codedir}/lib/puppet/{type,provider/test4847}"

  on agent, "cat > #{codedir}/lib/puppet/type/test4847.rb", :stdin => <<TYPE
Puppet::Type.newtype(:test4847) do
  newparam(:name, :namevar => true)
end
TYPE

  on agent, "cat > #{codedir}/lib/puppet/provider/test4847/only.rb", :stdin => <<PROVIDER
Puppet::Type.type(:test4847).provide(:only) do
  commands :anything => "#{codedir}/must_exist.exe"
  def self.instances
    warn "fact foo=\#{Facter.value('foo')}, snafu=\#{Facter.value('snafu')}"
    []
  end
end
PROVIDER

  foo_fact = <<FACT
Facter.add('foo') do
  setcode do
    'bar'
  end
end
FACT

  snafu_fact = <<FACT
Facter.add('snafu') do
  setcode do
    'zifnab'
  end
end
FACT

  on agent, puppet('apply'), :stdin => <<MANIFEST
  # The file name is chosen to work on Windows and *nix.
  file { "#{codedir}/must_exist.exe":
    ensure => file,
    mode   => "0755",
  }

  file { "#{codedir}/lib/facter/foo.rb":
    ensure  => file,
    content => "#{foo_fact}",
  }

  file { "#{codedir}/facts/snafu.rb":
    ensure  => file,
    content => "#{snafu_fact}"
  }
MANIFEST

  on agent, puppet('resource', 'test4847',
                   '--libdir', File.join(codedir, 'lib'),
                   '--factpath', File.join(codedir, 'facts')) do
    assert_match(/fact foo=bar, snafu=zifnab/, stderr)
  end

  teardown do
    on(agent, "rm -rf #{codedir}")
  end
end
