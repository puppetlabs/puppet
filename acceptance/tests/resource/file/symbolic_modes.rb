test_name "file resource: symbolic modes"

require 'test/unit/assertions'

module FileModeAssertions
  include Test::Unit::Assertions

  def assert_create(agent, manifest, path, expected_mode)
    testcase.apply_manifest_on(agent, manifest) do
      assert_match(/File\[#{Regexp.escape(path)}\]\/ensure: created/, testcase.stdout, "Failed to create #{path}")
    end

    assert_mode(agent, path, expected_mode)
  end

  def assert_mode(agent, path, expected_mode)
    current_mode = testcase.on(agent, "stat --format '%a' #{path}").stdout.chomp.to_i(8)
    assert_equal(expected_mode, current_mode, "current mode #{current_mode.to_s(8)} doesn't match expected mode #{expected_mode.to_s(8)}")
  end

  def assert_mode_change(agent, manifest, path, symbolic_mode, start_mode, expected_mode)
    testcase.apply_manifest_on(agent, manifest) do
      assert_match(/mode changed '#{'%04o' % start_mode}' to '#{'%04o' % expected_mode}'/, testcase.stdout,
                   "couldn't set mode to #{symbolic_mode}")
    end

    assert_mode(agent, path, expected_mode)
  end

  def assert_no_mode_change(agent, manifest)
    testcase.apply_manifest_on(agent, manifest) do
      assert_no_match(/mode changed/, testcase.stdout, "reapplied the symbolic mode change")
    end
  end
end

class ActionModeTest
  include FileModeAssertions

  attr_reader :testcase

  def initialize(testcase, agent, basedir, symbolic_mode)
    @testcase = testcase
    @agent = agent
    @basedir = basedir
    @symbolic_mode = symbolic_mode

    @file = "#{basedir}/file"
    @dir =  "#{basedir}/dir"

    testcase.on(agent, "rm -rf #{@file} #{@dir}")
  end

  def get_manifest(path, type, symbolic_mode)
    "file { #{path.inspect}: ensure => #{type}, mode => '#{symbolic_mode}' }"
  end
end

class CreatesModeTest < ActionModeTest
  def initialize(testcase, agent, basedir, symbolic_mode)
    super(testcase, agent, basedir, symbolic_mode)
  end

  def assert_file_mode(expected_mode)
    manifest = get_manifest(@file, 'file', @symbolic_mode)
    assert_create(@agent, manifest, @file, expected_mode)
    assert_no_mode_change(@agent, manifest)
  end

  def assert_dir_mode(expected_mode)
    manifest = get_manifest(@dir, 'directory', @symbolic_mode)
    assert_create(@agent, manifest, @dir, expected_mode)
    assert_no_mode_change(@agent, manifest)
  end
end

class ModifiesModeTest < ActionModeTest
  def initialize(testcase, agent, basedir, symbolic_mode, start_mode)
    super(testcase, agent, basedir, symbolic_mode)

    @start_mode = start_mode

    user = agent['user']
    group = agent['group'] || user

    testcase.on(agent, "touch #{@file} && chown #{user}:#{group} #{@file} && chmod #{start_mode.to_s(8)} #{@file}")
    testcase.on(agent, "mkdir -p #{@dir} && chown #{user}:#{group} #{@dir} && chmod #{start_mode.to_s(8)} #{@dir}")
  end

  def assert_file_mode(expected_mode)
    manifest = get_manifest(@file, 'file', @symbolic_mode)
    if @start_mode != expected_mode
      assert_mode_change(@agent, manifest, @file, @symbolic_mode, @start_mode, expected_mode)
    end
    assert_no_mode_change(@agent, manifest)
  end

  def assert_dir_mode(expected_mode)
    manifest = get_manifest(@dir, 'directory', @symbolic_mode)
    if @start_mode != expected_mode
      assert_mode_change(@agent, manifest, @dir, @symbolic_mode, @start_mode, expected_mode)
    end
    assert_no_mode_change(@agent, manifest)
  end
end

class ModeTest
  def initialize(testcase, agent, basedir)
    @testcase = testcase
    @agent = agent
    @basedir = basedir
  end

  def assert_creates(symbolic_mode, file_mode, dir_mode)
    creates = CreatesModeTest.new(@testcase, @agent, @basedir, symbolic_mode)
    creates.assert_file_mode(file_mode)
    creates.assert_dir_mode(dir_mode)
  end

  def assert_modifies(symbolic_mode, start_mode, file_mode, dir_mode)
    modifies = ModifiesModeTest.new(@testcase, @agent, @basedir, symbolic_mode, start_mode)
    modifies.assert_file_mode(file_mode)
    modifies.assert_dir_mode(dir_mode)
  end
end

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
# On Solaris 11 (from man chmod):
#
# 20#0    Set group ID on execution if # is 7, 5, 3, or 1.
#         Enable mandatory locking if # is 6, 4, 2, or 0.
#         ...
#         For directories, the set-gid bit can
#         only be set or cleared by using symbolic mode.

# From http://www.gnu.org/software/coreutils/manual/html_node/Symbolic-Modes.html#Symbolic-Modes
# Users
# u  the user who owns the file;
# g  other users who are in the file's group;
# o  all other users;
# a  all users; the same as 'ugo'.
#
# Operations
# + to add the permissions to whatever permissions the users already have for the file;
# - to remove the permissions from whatever permissions the users already have for the file;
# = to make the permissions the only permissions that the users have for the file.
#
# Permissions
# r the permission the users have to read the file;
# w the permission the users have to write to the file;
# x the permission the users have to execute the file, or search it if it is a directory.
# s the meaning depends on which user (uga) the permission is associated with:
#     to set set-user-id-on-execution, use 'u' in the users part of the symbolic mode and 's' in the permissions part.
#     to set set-group-id-on-execution, use 'g' in the users part of the symbolic mode and 's' in the permissions part.
#     to set both user and group-id-on-execution, omit the users part of the symbolic mode (or use 'a') and use 's' in the permissions part.
# t the restricted deletion flag (sticky bit), omit the users part of the symbolic mode (or use 'a') and use 't' in the permissions part.
# X execute/search permission is affected only if the file is a directory or already had execute permission.
#
# Note we do not currently support the Solaris (l) permission:
# l mandatory file and record locking refers to a file's ability to have its reading or writing
#     permissions locked while a program is accessing that file.
#
agents.each do |agent|
  if agent['platform'].include?('windows')
    Log.warn("Pending: this does not currently work on Windows")
    next
  end
  is_solaris = agent['platform'].include?('solaris')

  basedir = agent.tmpdir('symbolic-modes')
  on(agent, "mkdir -p #{basedir}")

  test = ModeTest.new(self, agent, basedir)
  test.assert_creates('u=r',            00444, 00455)
  test.assert_creates('u=w',            00244, 00255)
  test.assert_creates('u=x',            00144, 00155)
  test.assert_creates('u=rw',           00644, 00655)
  test.assert_creates('u=rwx',          00744, 00755)
  test.assert_creates('u=rwxt',         01744, 01755)
  test.assert_creates('u=rwxs',         04744, 04755)
  test.assert_creates('u=rwxts',        05744, 05755)

  test.assert_creates('ug=r',           00444, 00445)
  test.assert_creates('ug=rw',          00664, 00665)
  test.assert_creates('ug=rwx',         00774, 00775)
  test.assert_creates('ug=rwxt',        01774, 01775)
  test.assert_creates('ug=rwxs',        06774, 06775)
  test.assert_creates('ug=rwxts',       07774, 07775)

  test.assert_creates('ugo=r',          00444, 00444)
  test.assert_creates('ugo=rw',         00666, 00666)
  test.assert_creates('ugo=rwx',        00777, 00777)
  test.assert_creates('ugo=rwxt',       01777, 01777)
  # # test.assert_creates('ugo=rwxs',       06777, 06777)  ## BUG, puppet creates 07777
  test.assert_creates('ugo=rwxts',      07777, 07777)

  test.assert_creates('u=rwx,go=rx',    00755, 00755)
  test.assert_creates('u=rwx,g=rx,o=r', 00754, 00754)
  test.assert_creates('u=rwx,g=rx,o=',  00750, 00750)
  test.assert_creates('a=rwx',          00777, 00777)

  test.assert_creates('u+r',            00644, 00755)
  test.assert_creates('u+w',            00644, 00755)
  test.assert_creates('u+x',            00744, 00755)

  test.assert_modifies('u+r',           00200, 00600, 00600)
  test.assert_modifies('u+r',           00600, 00600, 00600)
  test.assert_modifies('u+w',           00500, 00700, 00700)
  test.assert_modifies('u+w',           00400, 00600, 00600)
  test.assert_modifies('u+x',           00700, 00700, 00700)
  test.assert_modifies('u+x',           00600, 00700, 00700)
  test.assert_modifies('u+X',           00100, 00100, 00100)
  test.assert_modifies('u+X',           00200, 00300, 00300)
  test.assert_modifies('u+X',           00400, 00500, 00500)
  test.assert_modifies('a+X',           00700, 00711, 00711)

  test.assert_modifies('u+s',           00744, 04744, 04744)
  test.assert_modifies('g+s',           00744, 02744, 02744)
  test.assert_modifies('u+t',           00744, 01744, 01744)

  test.assert_modifies('u-r',           00200, 00200, 00200)
  test.assert_modifies('u-r',           00600, 00200, 00200)
  test.assert_modifies('u-w',           00500, 00500, 00500)
  test.assert_modifies('u-w',           00600, 00400, 00400)
  test.assert_modifies('u-x',           00700, 00600, 00600)
  test.assert_modifies('u-x',           00600, 00600, 00600)

  test.assert_modifies('u-s',           04744, 00744, 00744)
  # using chmod 2744 on a directory to set the startmode fails on Solaris
  test.assert_modifies('g-s',           02744, 00744, 00744) unless is_solaris
  test.assert_modifies('u-t',           01744, 00744, 00744)

  # these raise
  # test.assert_raises('')
  # test.assert_raises(' ')
  # test.assert_raises('u=X')
  # test.assert_raises('u-X')
  # test.assert_raises('+l')
  # test.assert_raises('-l')

  step "clean up old test things"
  on agent, "rm -rf #{basedir}"
end
