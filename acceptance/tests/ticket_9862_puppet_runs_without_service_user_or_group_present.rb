test_name "#9862: puppet runs without service user or group present"

# puppet doesn't try to manage ownership on windows.
confine :except, :platform => 'windows'

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils
initialize_temp_dirs

def assert_ownership(agent, location, expected_user, expected_group)
  on(agent, "stat --format '%U:%G' #{location}") do
    assert_match(/#{expected_user}:#{expected_group}/, stdout)
  end
end

def missing_directory_for(agent, dir)
  agent_dir = get_test_file_path(agent, dir)
  on agent, "rm -rf #{agent_dir}"
  agent_dir
end

teardown do
  agents.each do |agent|
    step "ensure puppet resets it's user/group settings"
    on agent, puppet('apply', '-e', '"notify { puppet_run: }"')
    on agent, "find #{agent['puppetvardir']} -user existinguser" do
      assert_equal('',stdout)
    end
    on agent, puppet('resource', 'user', 'existinguser', 'ensure=absent')
    on agent, puppet('resource', 'group', 'existinggroup', 'ensure=absent')
  end
end

step "when the user and group are missing"
agents.each do |agent|
  logdir = missing_directory_for(agent, 'log')

  on agent, puppet('apply',
                   '-e', '"notify { puppet_run: }"',
                   '--logdir', logdir,
                   '--user', 'missinguser',
                   '--group', 'missinggroup') do

    assert_match(/puppet_run/, stdout)
    assert_ownership(agent, logdir, 'root', 'root')
  end
end

step "when the user and group exist"
agents.each do |agent|
  logdir = missing_directory_for(agent, 'log')

  on agent, puppet('resource', 'user', 'existinguser', 'ensure=present')
  on agent, puppet('resource', 'group', 'existinggroup', 'ensure=present')

  on agent, puppet('apply',
                   '-e', '"notify { puppet_run: }"',
                   '--logdir', logdir,
                   '--user', 'existinguser',
                   '--group', 'existinggroup') do

    assert_match(/puppet_run/, stdout)
    assert_ownership(agent, logdir, 'existinguser', 'existinggroup')
  end
end
