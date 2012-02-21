test_name "file resource: symbolic modes"

def validate(path, mode)
  "ruby -e 'exit (File::Stat.new(#{path.inspect}).mode & 0777 == #{mode})'"
end

agents.each do |agent|
  if agent['platform'].include?('windows')
    Log.warn("Pending: this does not currently work on Windows")
    next
  end

  user = agent['user']
  group = agent['group'] || user
  file = agent.tmpfile('symbolic-mode-file')
  dir = agent.tmpdir('symbolic-mode-dir')

  on(agent, "touch #{file} ; mkdir -p #{dir}")

# Infrastructure for a nice, table driven test.  Yum.
#
# For your reference:
# 4000    the set-user-ID-on-execution bit
# 2000    the set-group-ID-on-execution bit
# 1000    the sticky bit
# 0400    Allow read by owner.
# 0200    Allow write by owner.
# 0100    For files, allow execution by owner.  For directories, allow the
#         owner to search in the directory.
# 0040    Allow read by group members.
# 0020    Allow write by group members.
# 0010    For files, allow execution by group members.  For directories, allow
#         group members to search in the directory.
# 0004    Allow read by others.
# 0002    Allow write by others.
# 0001    For files, allow execution by others.  For directories allow others
#         to search in the directory.
#
# fields are:  start_mode, symbolic_mode, file_mode, dir_mode
# start_mode is passed to chmod on the target platform
# symbolic_mode is the mode set in our test
# the file and dir mode values are the numeric resultant values we should get
tests = <<END
0000   u=rwx     0700  0700
0000   ug=rwx    0770  0770
0000   ugo=rwx   0777  0777
0000   u=r       0400  0400
0000   u=w       0200  0200
0000   u=x       0100  0100

0500   u+w       0700  0700
0400   u+w       0600  0600
0200   u+r       0600  0600

0100   u+X       0100  0100
0200   u+X       0300  0300
0400   u+X       0500  0500
END

tests.split("\n").map {|x| x.split(/\s+/)}.each do |data|
  # Might as well skip blank lines.
  next if data.empty? or data.any? {|x| x.nil? or x.empty? }

  # Make sure our interpretation of the data is reasonable.
  start_mode    = '%04o' % data[0].to_i(8)
  # inspect quotes the string in a way that is both shell, and manifest, safe;
  # since almost every use of it is in one of those places, this saves quite
  # some effort otherwise handling the value.
  symbolic_mode =          data[1].inspect
  file_mode     = '%04o' % data[2].to_i(8)
  dir_mode      = '%04o' % data[3].to_i(8)

  step "ensure permissions for testing #{symbolic_mode}"
  on agent, "chmod #{start_mode} #{file} && chown #{user}:#{group} #{file}"
  on agent, "chmod #{start_mode} #{dir}  && chown #{user}:#{group} #{dir}"

  step "test mode #{symbolic_mode} works on a file"
  manifest = "file { #{file.inspect}: ensure => file, mode => #{symbolic_mode} }"
  apply_manifest_on(agent, manifest) do
    unless start_mode == file_mode
      assert_match(/mode changed '#{start_mode}' to '#{file_mode}'/, stdout,
                   "couldn't set file mode to #{symbolic_mode}")
    end
  end

  step "validate the mode changes applied to the file"
  on agent, "test -f #{file} && " + validate(file, file_mode)

  # Validate that we don't reapply the changes - that they are stable.
  apply_manifest_on(agent, manifest) do
    assert_no_match(/mode changed/, stdout, "reapplied the symbolic mode change")
  end

  step "test mode #{symbolic_mode} works on a directory"
  manifest = "file { #{dir.inspect}: ensure => directory, mode => #{symbolic_mode} }"
  apply_manifest_on(agent, manifest) do
    unless start_mode == dir_mode
      assert_match(/mode changed '#{start_mode}' to '#{dir_mode}'/, stdout,
                   "couldn't set dir mode to #{symbolic_mode}")
    end
  end

  step "validate the mode changes applied to the dir"
  on agent, "test -d #{dir} && " + validate(file, dir_mode)

  # Validate that we don't reapply the changes - that they are stable.
  apply_manifest_on(agent, manifest) do
    assert_no_match(/mode changed/, stdout, "reapplied the symbolic mode change")
  end
end

step "clean up old test things"
on agent, "rm -rf #{file} #{dir}"
end
