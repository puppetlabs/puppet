test_name "#17371 file metadata specified in puppet.conf needs to be applied"

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

  create_test_file(agent, 'puppet.conf', <<-CONF)
  [master]
  logdir = #{logdir} { owner = root, group = root, mode = 0700 }
  manifest = #{get_test_file_path(agent, 'site.pp')}
  CONF

  on(agent, puppet('master', '--compile', 'fake_node', '--confdir', get_test_file_path(agent, '')))

  on(agent, "stat --format '%U:%G %a' #{logdir}") do
    assert_match(/root:root 700/, stdout)
  end
end
