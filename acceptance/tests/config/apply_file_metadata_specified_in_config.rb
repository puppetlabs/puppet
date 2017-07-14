test_name "C4580 - file metadata specified in puppet.conf needs to be applied"

tag 'audit:low',
    'audit:acceptance'

# when owner/group works on windows for settings, this confine should be removed.
confine :except, :platform => 'windows'
confine :except, :platform => /solaris-10/ # See PUP-5200

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils
initialize_temp_dirs()

agents.each do |agent|
  logdir = get_test_file_path(agent, 'log')

  create_test_file(agent, 'site.pp', <<-SITE)
  node default {
    notify { puppet_run: }
  }
  SITE

  user = root_user(agent)
  group = root_group(agent)

  # puppet only always the group to be 'root' or 'service', but not
  # all platforms have a 'root' group, e.g. osx.
  permissions =
    if group == 'root'
      "{ owner = #{user}, group = root, mode = 0700 }"
    else
      "{ owner = #{user}, mode = 0700 }"
    end

  on(agent, puppet('config', 'set', 'logdir', "'#{logdir} #{permissions}'", '--confdir', get_test_file_path(agent, '')))

  on(agent, puppet('apply', get_test_file_path(agent, 'site.pp'), '--confdir', get_test_file_path(agent, '')))

  permissions = stat(agent, logdir)
  assert_equal(user, permissions[0], "File owner #{permissions[0]} does not match expected user #{user}")
  assert_equal(group, permissions[1], "File group #{permissions[1]} does not match expected group #{group}")
  assert_equal(0700, permissions[2], "File mode #{permissions[2].to_s(8)} does not match expected mode 0700")
end
