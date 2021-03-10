test_name "Windows Exec `exit_code` Parameter Acceptance Test"

tag 'risk:medium',
    'audit:medium',
    'audit:refactor',   # Use block style `test_name`
    'audit:integration' # exec resource succeeds when the `exit_code` parameter
                        # is given a windows specific exit code and a exec
                        # returns that exit code, ie. it either correctly matches
                        # exit_code parameter to returned exit code, or ignores both (;

confine :to, :platform => 'windows'

pass_exitcode_manifest = <<-MANIFEST
winexitcode::execute { '0':
  exit_code => 0
}
MANIFEST

upper_8bit_boundary_manifest = <<-MANIFEST
winexitcode::execute { '255':
  exit_code => 255
}
MANIFEST

cross_8bit_boundary_manifest = <<-MANIFEST
winexitcode::execute { '256':
  exit_code => 256
}
MANIFEST

upper_32bit_boundary_manifest = <<-MANIFEST
winexitcode::execute { '4294967295':
  exit_code => 4294967295
}
MANIFEST

cross_32bit_boundary_manifest = <<-MANIFEST
winexitcode::execute { '4294967296':
  exit_code => 0
}
MANIFEST

negative_boundary_manifest = <<-MANIFEST
winexitcode::execute { '-1':
  exit_code => 4294967295
}
MANIFEST

step "Install Custom Module for Testing"

agents.each do |agent|
  if (on(agent, puppet("--version")).stdout.split('.')[0].to_i < 4)
    module_path_config_property = "confdir"
  else
    module_path_config_property = "codedir"
  end

  native_modules_path = on(agent, puppet("config print #{module_path_config_property}")).stdout.gsub('C:', '/cygdrive/c').strip

  #Check to see if we are running on Windows 2003. Do a crazy hack to get around SCP issues.
  if (on(agent, facter("find operatingsystemmajrelease")).stdout =~ /2003/)
    on(agent, "ln -s #{native_modules_path.gsub(/ /, '\ ')} /tmp/puppet_etc")
    modules_path = '/tmp/puppet_etc'
  else
    modules_path = native_modules_path
  end

  #Create the modules directory if it doesn't exist
  if on(agent, "test ! -d #{modules_path}/modules", :acceptable_exit_codes => [0,1]).exit_code == 0
    on(agent, "mkdir -p #{modules_path}/modules")
  end

  # copy custom module.
  scp_to(agent, File.expand_path(File.join(File.dirname(__FILE__), "winexitcode")), "#{modules_path}/modules")
end

agents.each do |agent|
  step "Verify '0' is a Valid Exit Code"

  #Apply the manifest and verify Puppet returns success.
  on(agent, puppet('apply', '--debug'), :stdin => pass_exitcode_manifest)

  step "Verify Unsigned 8bit Upper Boundary"

  #Apply the manifest and verify Puppet returns success.
  on(agent, puppet('apply', '--debug'), :stdin => upper_8bit_boundary_manifest)

  step "Verify Unsigned 8bit Cross Boundary"

  #Apply the manifest and verify Puppet returns success.
  on(agent, puppet('apply', '--debug'), :stdin => cross_8bit_boundary_manifest)

  step "Verify Unsigned 32bit Upper Boundary"

  #Apply the manifest and verify Puppet returns success.
  on(agent, puppet('apply', '--debug'), :stdin => upper_32bit_boundary_manifest)

  step "Verify Unsigned 32bit Cross Boundary"

  #Apply the manifest and verify Puppet returns success.
  on(agent, puppet('apply', '--debug'), :stdin => cross_32bit_boundary_manifest)

  step "Verify Negative Exit Code Rollover Boundary"

  #Apply the manifest and verify Puppet returns success.
  on(agent, puppet('apply', '--debug'), :stdin => negative_boundary_manifest)
end
