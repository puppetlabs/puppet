test_name "providers should be useable in the same run they become suitable"

tag 'audit:high',       # autoloader, core puppet agent run functionality
    'audit:refactor',    # Use block style `test_name`
    'audit:integration' # does not require packages, probably implicitly assumed in many other places

agents.each do |agent|
  dir = agent.tmpdir('provider-6907')

  on agent, "mkdir -p #{dir}/lib/puppet/{type,provider/test6907}"
  on agent, "cat > #{dir}/lib/puppet/type/test6907.rb", :stdin => <<TYPE
Puppet::Type.newtype(:test6907) do
  newparam(:name, :namevar => true)

  newproperty(:file)
end
TYPE

  on agent, "cat > #{dir}/lib/puppet/provider/test6907/only.rb", :stdin => <<PROVIDER
Puppet::Type.type(:test6907).provide(:only) do
  # The name of the file is chosen to be *.exe so it works on windows and *nix
  # because windows inspects the PATHEXT environment variable in 1.9.3 and later.
  commands :anything => "#{dir}/must_exist.exe"
  require 'fileutils'

  def file
    'not correct'
  end

  def file=(value)
    FileUtils.touch(value)
  end
end
PROVIDER

  on agent, puppet_apply("--libdir #{dir}/lib --trace"), :stdin => <<MANIFEST
  test6907 { "test-6907":
    file => "#{dir}/test_file",
  }

  # The name of the file is chosen to be *.exe so it works on windows and *nix
  # because windows inspects the PATHEXT environment variable in 1.9.3 and later.
  file { "#{dir}/must_exist.exe":
    ensure => file,
    mode => "0755",
  }
MANIFEST

  on agent, "ls #{dir}/test_file"
end
