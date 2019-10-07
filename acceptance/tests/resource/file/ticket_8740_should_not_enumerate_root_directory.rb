test_name "#8740: should not enumerate root directory"
confine :except, :platform => 'windows'
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:acceptance'

target = "/test-socket-#{$$}"

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CommandUtils

agents.each do |agent|
  step "clean up the system before we begin"
  on(agent, "rm -f #{target}")

  step "create UNIX domain socket"
  on(agent, "#{ruby_command(agent)} -e \"require 'socket'; UNIXServer::new('#{target}').close\"")

  step "query for all files, which should return nothing"
  on(agent, puppet_resource('file'), :acceptable_exit_codes => [1]) do
    assert_match(%r{Listing all file instances is not supported.  Please specify a file or directory, e.g. puppet resource file /etc}, stderr)
  end

  ["/", "/etc"].each do |file|
    step "query '#{file}' directory, which should return single entry"
    on(agent, puppet_resource('file', file)) do
      files = stdout.scan(/^file \{ '([^']+)'/).flatten

      assert_equal(1, files.size, "puppet returned multiple files: #{files.join(', ')}")
      assert_match(file, files[0], "puppet did not return file")
    end
  end

  step "query file that does not exist, which should report the file is absent"
  on(agent, puppet_resource('file', '/this/does/notexist')) do
    assert_match(/ensure\s+=>\s+'absent'/, stdout)
  end

  step "remove UNIX domain socket"
  on(agent, "rm -f #{target}")
end
