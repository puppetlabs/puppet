test_name "Exercise a module with 4x function and 4x system function"

# Purpose:
# Test that a packed puppet can call a 4x system function, and that a 4x function in
# a module can be called.
#
# Method:
# * Manually construct a very simple module with a manifest that creates a file.
# * The file has content that depends on logic that calls both a system function (reduce), and
#   a function supplied in the module (helloworld::mul10).
# * The module is manually constructed to allow the test to also run on Windows where the module tool
#   is not supported.
# * The module is included by calling 'include' from 'puppet apply'.
# * Puppet apply is executed to generate the file with the content.
# * The generated contents is asserted.

# TODO: The test can be improved by adding yet another module that calls the function in helloworld.
# TODO: The test can be improved to also test loading of a non namespaced function

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

tag 'audit:medium',
    'audit:unit'    # This should be covered adequately by unit tests

initialize_temp_dirs

agents.each do |agent|
  # The modulepath to use in environment 'dev'
  envs_path = get_test_file_path(agent, 'environments')
  dev_modulepath = get_test_file_path(agent, 'environments/dev/modules')
  target_path = get_test_file_path(agent, 'output')
  mkdirs agent, target_path

  # make sure that we use the modulepath from the dev environment
  puppetconf = get_test_file_path(agent, 'puppet.conf')
  on agent, puppet("config", "set", "environmentpath", envs_path, "--section", "main", "--config", puppetconf)
  on agent, puppet("config", "set", "environment", "dev", "--section", "user", "--config", puppetconf)

  # Where the functions in the written modules should go
  helloworld_functions = 'helloworld/lib/puppet/functions/helloworld'
  # Clean out the module that will be written to ensure no interference from a previous run
  on agent, "rm -rf #{File.join(dev_modulepath, 'helloworld')}"
  mkdirs agent, File.join(dev_modulepath, helloworld_functions)

  # Write a module
  # Write the function helloworld::mul10, that multiplies its argument by 10
  create_remote_file(agent, File.join(dev_modulepath, helloworld_functions, "mul10.rb"), <<'SOURCE')
Puppet::Functions.create_function(:'helloworld::mul10') do
  def mul10(x)
    x * 10
  end
end
SOURCE

  # Write a manifest that calls a 4x function (reduce), and calls a function defined in the module
  # (helloworld::mul10).
  #
  mkdirs agent, File.join(dev_modulepath, "helloworld", "manifests")
  create_remote_file(agent, File.join(dev_modulepath, "helloworld", "manifests", "init.pp"), <<SOURCE)
class helloworld {
  file { "#{target_path}/result.txt":
    ensure => 'file',
    mode => '0666',
    content => [1,2,3].reduce("Generated") |$memo, $n| {
      "${memo}, ${n} => ${helloworld::mul10($n)}"
    }
  }
}
SOURCE

  # Run apply to generate the file with the output
  on agent, puppet('apply', '-e', "'include helloworld'", '--config', puppetconf)

  # Assert that the file was written with the generated content
  on(agent, "cat #{File.join(target_path, 'result.txt')}") do
    assert_match(/^Generated, 1 => 10, 2 => 20, 3 => 30$/, stdout, "Generated the wrong content")
  end

end
