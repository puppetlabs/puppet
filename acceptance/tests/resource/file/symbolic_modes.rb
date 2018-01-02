test_name 'file resource: symbolic modes' do
  confine :except, :platform => /^eos-/ # See ARISTA-37
  confine :except, :platform => /^solaris-10/
  confine :except, :platform => /^windows/
  confine :to, {}, hosts.select {|host| !host[:roles].include?('master')}
  tag 'audit:high',
      'audit:acceptance'

  require 'puppet/acceptance/temp_file_utils'
  extend Puppet::Acceptance::TempFileUtils

  class FileSymlink
    attr_reader :mode, :path, :start_mode, :symbolic_mode

    def initialize(base_dir, file_type, symbolic_mode, mode, start_mode=nil)
      @base_dir      = base_dir
      @file_type     = file_type
      @symbolic_mode = symbolic_mode
      @mode          = mode
      @start_mode    = start_mode

      if @start_mode.nil?
        @path= "#{@base_dir}/#{@file_type}_#{@symbolic_mode}_#{@mode.to_s(8)}"
      else
        @path= "#{@base_dir}/#{@file_type}_#{@symbolic_mode}_#{@start_mode.to_s(8)}_#{@mode.to_s(8)}"
      end
    end

    # does the mode of the file/directory change from start_mode to puppet apply
    def mode_changes?
      ! @start_mode.nil? && @start_mode != @mode
    end

    def get_manifest
      "file { #{@path.inspect}: ensure => '#{@file_type}', mode => '#{@symbolic_mode}' }"
    end
  end

  class BaseTest
    include Beaker::DSL::Assertions

    def initialize(testcase, agent, base_dir)
      @testcase       = testcase
      @agent          = agent
      @base_dir       = base_dir
      @file_list      = []
      @directory_list = []
    end

    def assert_mode(agent, path, expected_mode)
      permissions = @testcase.stat(agent, path)
      assert_equal(expected_mode, permissions[2], "'#{path}' current mode #{permissions[2].to_s(8)} doesn't match expected mode #{expected_mode.to_s(8)}")
    end

    def manifest
      manifest_array = (@file_list + @directory_list).map {|x| x.get_manifest}
      @testcase.step(manifest_array)
      manifest_array.join("\n")
    end

    def puppet_reapply
      @testcase.apply_manifest_on(@agent, manifest) do |apply_result|
        assert_no_match(/mode changed/, apply_result.stdout, "reapplied the symbolic mode change")
        (@file_list + @directory_list).each do |file|
          assert_no_match(/#{Regexp.escape(file.path)}/, apply_result.stdout, "Expected to not see '#{file.path}' in 'puppet apply' output")
        end
      end
    end
  end

  class CreateTest < BaseTest

    def symlink_file(symbolic_mode, mode)
      @file_list << FileSymlink.new(@base_dir, 'file', symbolic_mode, mode)
    end

    def symlink_directory(symbolic_mode, mode)
      @directory_list << FileSymlink.new(@base_dir, 'directory', symbolic_mode, mode)
    end

    def puppet_apply
      apply_result = @testcase.apply_manifest_on(@agent, manifest).stdout
      (@file_list + @directory_list).each do |file|
        assert_match(/File\[#{Regexp.escape(file.path)}\]\/ensure: created/, apply_result, "Failed to create #{file.path}")
        assert_mode(@agent, file.path, file.mode)
      end
    end
  end

  class ModifyTest < BaseTest

    def symlink_file(symbolic_mode, start_mode, mode)
      @file_list << FileSymlink.new(@base_dir, 'file', symbolic_mode, mode, start_mode)
    end

    def symlink_directory(symbolic_mode, start_mode, mode)
      @directory_list << FileSymlink.new(@base_dir, 'directory', symbolic_mode, mode, start_mode)
    end

    def create_starting_state
      files       = @file_list.collect {|x| "'#{x.path}'" }
      directories = @directory_list.collect {|x| "'#{x.path}'" }

      @testcase.on(@agent, "touch #{files.join(' ')}")
      @testcase.on(@agent, "mkdir -p #{directories.join(' ')}")
      @testcase.on(@agent, "chown symuser:symgroup #{files.join(' ')} #{directories.join(' ')}")
      cmd_list = []
      (@file_list + @directory_list).each do |file|
        cmd_list << "chmod #{file.start_mode.to_s(8)} '#{file.path}'"
      end
      @testcase.on(@agent, cmd_list.join(' && '))
    end

    def puppet_apply
      @testcase.step(manifest)
      apply_result = @testcase.apply_manifest_on(@agent, manifest).stdout
      @testcase.step(apply_result)
      (@file_list + @directory_list).each do |file|
        if file.mode_changes?
          assert_match(/File\[#{Regexp.escape(file.path)}.* mode changed '#{'%04o' % file.start_mode}'.* to '#{'%04o' % file.mode}'/,
                       apply_result, "couldn't set mode to #{file.symbolic_mode}")
        else
          assert_no_match(/#{Regexp.escape(file.path)}.*mode changed/, apply_result, "reapplied the symbolic mode change for file #{file.path}")
        end
        assert_mode(@agent, file.path, file.mode)
      end
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

# From https://www.gnu.org/software/coreutils/manual/html_node/Symbolic-Modes.html#Symbolic-Modes
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
    is_solaris = agent['platform'].include?('solaris')

    on(agent, puppet('resource user symuser ensure=present'))
    on(agent, puppet('resource group symgroup ensure=present'))
    base_dir_create = agent.tmpdir('symbolic-modes-create_test')
    base_dir_modify = agent.tmpdir('symbolic-modes-modify_test')

    teardown do
      on(agent, puppet('resource user symuser ensure=absent'))
      on(agent, puppet('resource group symgroup ensure=absent'))
      on(agent, "rm -rf '#{base_dir_create}' '#{base_dir_modify}'")
    end

    create_test = CreateTest.new(self, agent, base_dir_create)
    create_test.symlink_file('u=r', 00444)
    create_test.symlink_file('u=w', 00244)
    create_test.symlink_file('u=x', 00144)
    create_test.symlink_file('u=rw', 00644)
    create_test.symlink_file('u=rwx', 00744)
    create_test.symlink_file('u=rwxt', 01744)
    create_test.symlink_file('u=rwxs', 04744)
    create_test.symlink_file('u=rwxts', 05744)

    create_test.symlink_file('ug=r', 00444)
    create_test.symlink_file('ug=rw', 00664)
    create_test.symlink_file('ug=rwx', 00774)
    create_test.symlink_file('ug=rwxt', 01774)
    create_test.symlink_file('ug=rwxs', 06774)
    create_test.symlink_file('ug=rwxts', 07774)

    create_test.symlink_file('ugo=r', 00444)
    create_test.symlink_file('ugo=rw', 00666)
    create_test.symlink_file('ugo=rwx', 00777)
    create_test.symlink_file('ugo=rwxt', 01777)
    #create_test.symlink_file('ugo=rwxs', 06777)  ## BUG, puppet creates 07777
    create_test.symlink_file('ugo=rwxts', 07777)

    create_test.symlink_file('u=rwx,go=rx', 00755)
    create_test.symlink_file('u=rwx,g=rx,o=r', 00754)
    create_test.symlink_file('u=rwx,g=rx,o=', 00750)
    create_test.symlink_file('a=rwx', 00777)

    create_test.symlink_file('u+r', 00644)
    create_test.symlink_file('u+w', 00644)
    create_test.symlink_file('u+x', 00744)
    create_test.symlink_directory('u=r', 00455)
    create_test.symlink_directory('u=w', 00255)
    create_test.symlink_directory('u=x', 00155)
    create_test.symlink_directory('u=rw', 00655)
    create_test.symlink_directory('u=rwx', 00755)
    create_test.symlink_directory('u=rwxt', 01755)
    create_test.symlink_directory('u=rwxs', 04755)
    create_test.symlink_directory('u=rwxts', 05755)

    create_test.symlink_directory('ug=r', 00445)
    create_test.symlink_directory('ug=rw', 00665)
    create_test.symlink_directory('ug=rwx', 00775)
    create_test.symlink_directory('ug=rwxt', 01775)
    create_test.symlink_directory('ug=rwxs', 06775)
    create_test.symlink_directory('ug=rwxts', 07775)

    create_test.symlink_directory('ugo=r', 00444)
    create_test.symlink_directory('ugo=rw', 00666)
    create_test.symlink_directory('ugo=rwx', 00777)
    create_test.symlink_directory('ugo=rwxt', 01777)
    #create_test.symlink_directory('ugo=rwxs', 06777)  ## BUG, puppet creates 07777
    create_test.symlink_directory('ugo=rwxts', 07777)

    create_test.symlink_directory('u=rwx,go=rx', 00755)
    create_test.symlink_directory('u=rwx,g=rx,o=r', 00754)
    create_test.symlink_directory('u=rwx,g=rx,o=', 00750)
    create_test.symlink_directory('a=rwx', 00777)

    create_test.symlink_directory('u+r', 00755)
    create_test.symlink_directory('u+w', 00755)
    create_test.symlink_directory('u+x', 00755)
    create_test.puppet_apply()
    create_test.puppet_reapply()

    modify_test = ModifyTest.new(self, agent, base_dir_modify)
    modify_test.symlink_file('u+r', 00200, 00600)
    modify_test.symlink_file('u+r', 00600, 00600)
    modify_test.symlink_file('u+w', 00500, 00700)
    modify_test.symlink_file('u+w', 00400, 00600)
    modify_test.symlink_file('u+x', 00700, 00700)
    modify_test.symlink_file('u+x', 00600, 00700)
    modify_test.symlink_file('u+X', 00100, 00100)
    modify_test.symlink_file('u+X', 00200, 00200)
    modify_test.symlink_file('u+X', 00410, 00510)
    modify_test.symlink_file('a+X', 00600, 00600)
    modify_test.symlink_file('a+X', 00700, 00711)

    modify_test.symlink_file('u+s', 00744, 04744)
    modify_test.symlink_file('g+s', 00744, 02744)
    modify_test.symlink_file('u+t', 00744, 01744)

    modify_test.symlink_file('u-r', 00200, 00200)
    modify_test.symlink_file('u-r', 00600, 00200)
    modify_test.symlink_file('u-w', 00500, 00500)
    modify_test.symlink_file('u-w', 00600, 00400)
    modify_test.symlink_file('u-x', 00700, 00600)
    modify_test.symlink_file('u-x', 00600, 00600)

    modify_test.symlink_file('u-s', 04744, 00744)
    modify_test.symlink_file('g-s', 02744, 00744)
    modify_test.symlink_file('u-t', 01744, 00744)

    modify_test.symlink_directory('u+r', 00200, 00600)
    modify_test.symlink_directory('u+r', 00600, 00600)
    modify_test.symlink_directory('u+w', 00500, 00700)
    modify_test.symlink_directory('u+w', 00400, 00600)
    modify_test.symlink_directory('u+x', 00700, 00700)
    modify_test.symlink_directory('u+x', 00600, 00700)
    modify_test.symlink_directory('u+X', 00100, 00100)
    modify_test.symlink_directory('u+X', 00200, 00300)
    modify_test.symlink_directory('u+X', 00410, 00510)
    modify_test.symlink_directory('a+X', 00600, 00711)
    modify_test.symlink_directory('a+X', 00700, 00711)

    modify_test.symlink_directory('u+s', 00744, 04744)
    modify_test.symlink_directory('g+s', 00744, 02744)
    modify_test.symlink_directory('u+t', 00744, 01744)

    modify_test.symlink_directory('u-r', 00200, 00200)
    modify_test.symlink_directory('u-r', 00600, 00200)
    modify_test.symlink_directory('u-w', 00500, 00500)
    modify_test.symlink_directory('u-w', 00600, 00400)
    modify_test.symlink_directory('u-x', 00700, 00600)
    modify_test.symlink_directory('u-x', 00600, 00600)

    modify_test.symlink_directory('u-s', 04744, 00744)
    # using chmod 2744 on a directory to set the start_mode fails on Solaris
    modify_test.symlink_directory('g-s', 02744, 00744) unless is_solaris
    modify_test.symlink_directory('u-t', 01744, 00744)
    modify_test.create_starting_state
    modify_test.puppet_apply
    modify_test.puppet_reapply

    # these raise
    # test.assert_raises('')
    # test.assert_raises(' ')
    # test.assert_raises('u=X')
    # test.assert_raises('u-X')
    # test.assert_raises('+l')
    # test.assert_raises('-l')
  end
end
