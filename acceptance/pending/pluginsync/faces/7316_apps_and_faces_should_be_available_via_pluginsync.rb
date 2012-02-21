test_name "the pluginsync functionality should sync app definitions, and they should be runnable afterwards"

#
# This test is intended to ensure that pluginsync syncs app and face definitions to the agents.
# Further, the apps and faces should be runnable on the agent after the sync has occurred.
#
# (NOTE: When this test is passing, it should resolve both #7316 re: verifying that apps/faces can
#  be run on the agent node after a plugin sync, and #6753 re: being able to run a face without
#  having a placeholder stub file in the "applications" directory.)
#

###############################################################################
# BEGIN UTILITY METHODS - ideally this stuff would live somewhere besides in
#  the actual test.
###############################################################################

# Create a file on the host.
# Parameters:
# [host] the host to create the file on
# [file_path] the path to the file to be created
# [file_content] a string containing the contents to be written to the file
# [options] a hash containing additional behavior options.  Currently supported:
# * :mkdirs (default false) if true, attempt to create the parent directories on the remote host before writing
#       the file
# * :owner (default 'root') the username of the user that the file should be owned by
# * :group (default 'puppet') the name of the group that the file should be owned by
# * :mode (default '644') the mode (file permissions) that the file should be created with
def create_test_file(host, file_rel_path, file_content, options)

  # set default options
  options[:mkdirs] ||= false
  options[:owner] ||= "root"
  options[:group] ||= "puppet"
  options[:mode] ||= "755"

  file_path = get_test_file_path(host, file_rel_path)

  mkdirs(host, File.dirname(file_path)) if (options[:mkdirs] == true)
  create_remote_file(host, file_path, file_content)

#
# NOTE: we need these chown/chmod calls because the acceptance framework connects to the nodes as "root", but
#  puppet 'master' runs as user 'puppet'.  Therefore, in order for puppet master to be able to read any files
#  that we've created, we have to carefully set their permissions
#

  chown(host, options[:owner], options[:group], file_path)
  chmod(host, options[:mode], file_path)

end


# Given a relative path, returns an absolute path for a test file.  Basically, this just prepends the
# a unique temp dir path (specific to the current test execution) to your relative path.
def get_test_file_path(host, file_rel_path)
  File.join(@host_test_tmp_dirs[host.name], file_rel_path)
end


# Check for the existence of a temp file for the current test; basically, this just calls file_exists?(),
# but prepends the path to the current test's temp dir onto the file_rel_path parameter.  This allows
# tests to be written using only a relative path to specify file locations, while still taking advantage
# of automatic temp file cleanup at test completion.
def test_file_exists?(host, file_rel_path)
  # I don't think we can easily use "test -f" here, because our "execute" commands are all built around reading
  # stdout as opposed to reading process exit codes
  result = host.execute("ruby -e \"print File.exists?('#{get_test_file_path(host, file_rel_path)}')\"")
  # get a boolean return value
  result == "true"
end

def tmpdir(host, basename)
  host_tmpdir = host.tmpdir(basename)
  # we need to make sure that the puppet user can traverse this directory...
  chmod(host, "755", host_tmpdir)
  host_tmpdir
end

def mkdirs(host, dir_path)
  on(host, "mkdir -p #{dir_path}")
end

def chown(host, owner, group, path)
  on(host, "chown #{owner}:#{group} #{path}")
end

def chmod(host, mode, path)
  on(host, "chmod #{mode} #{path}")
end




# pluck this out of the test case environment; not sure if there is a better way
cur_test_file = @path
cur_test_file_shortname = File.basename(cur_test_file, File.extname(cur_test_file))

# we need one list of all of the hosts, to assist in managing temp dirs.  It's possible
# that the master is also an agent, so this will consolidate them into a unique set
all_hosts = Set[master, *agents]

# now we can create a hash of temp dirs--one per host, and unique to this test--without worrying about
# doing it twice on any individual host
@host_test_tmp_dirs = Hash[all_hosts.map do |host| [host.name, tmpdir(host, cur_test_file_shortname)] end ]

# a silly variable for keeping track of whether or not all of the tests passed...
all_tests_passed = false

###############################################################################
# END UTILITY METHODS
###############################################################################



###############################################################################
# BEGIN TEST LOGIC
###############################################################################

# create some vars to point to the directories that we're going to point the master/agents at
master_module_dir = "master_modules"
agent_lib_dir = "agent_lib"

app_name = "superbogus"
app_desc = "a simple %1$s for testing %1$s delivery via plugin sync"
app_output = "Hello from the #{app_name} %s"

master_module_file_content = {}

master_module_file_content["application"] = <<-HERE
require 'puppet/application'

class Puppet::Application::#{app_name.capitalize} < Puppet::Application

  def help
    <<-HELP

puppet-#{app_name}(8) -- #{app_desc % "application"}
========
    HELP
  end

  def main()
    puts("#{app_output % "application"}")
  end
end
HERE


master_module_file_content["face"] = <<-HERE
Puppet::Face.define(:#{app_name}, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "#{app_desc % "face"}"

  action(:foo) do
    summary "a test action defined in the test face in the main puppet lib dir"

    default
    when_invoked do |*args|
      puts "#{app_output % "face"}"
    end
  end

end
HERE



# this begin block is here for handling temp file cleanup via an "ensure" block at the very end of the
# test.
begin

  modes = ["application", "face"]

  modes.each do |mode|

    # here we create a custom app, which basically doesn't do anything except for print a hello-world message
    agent_module_app_file = "#{agent_lib_dir}/puppet/#{mode}/#{app_name}.rb"
    master_module_app_file = "#{master_module_dir}/#{app_name}/lib/puppet/#{mode}/#{app_name}.rb"


    # copy all the files to the master
    step "write our simple module out to the master" do
      create_test_file(master, master_module_app_file, master_module_file_content[mode], :mkdirs => true)
    end

    step "verify that the app file exists on the master" do
      unless test_file_exists?(master, master_module_app_file) then
        fail_test("Failed to create app file '#{get_test_file_path(master, master_module_app_file)}' on master")
      end
    end

    step "start the master" do
      with_master_running_on(master,
             "--modulepath=\"#{get_test_file_path(master, master_module_dir)}\"") do

        # the module files shouldn't exist on the agent yet because they haven't been synced
        step "verify that the module files don't exist on the agent path" do
          agents.each do |agent|
              if test_file_exists?(agent, agent_module_app_file) then
                fail_test("app file already exists on agent: '#{get_test_file_path(agent, agent_module_app_file)}'")
              end
          end
        end

        step "run the agent" do
          agents.each do |agent|
            run_agent_on(agent, "--trace --libdir=\"#{get_test_file_path(agent, agent_lib_dir)}\" " +
                                "--no-daemonize --verbose --onetime --test --server #{master}")
          end
        end

      end
    end

    step "verify that the module files were synced down to the agent" do
      agents.each do |agent|
        unless test_file_exists?(agent, agent_module_app_file) then
          fail_test("Expected app file not synced to agent: '#{get_test_file_path(agent, agent_module_app_file)}'")
        end
      end
    end

    step "verify that the application shows up in help" do
      agents.each do |agent|
        on(agent, PuppetCommand.new(:help, "--libdir=\"#{get_test_file_path(agent, agent_lib_dir)}\"")) do
          assert_match(/^\s+#{app_name}\s+#{app_desc % mode}$/, result.stdout)
        end
      end
    end

    step "verify that we can run the application" do
      agents.each do |agent|
        on(agent, PuppetCommand.new(:"#{app_name}", "--libdir=\"#{get_test_file_path(agent, agent_lib_dir)}\"")) do
          assert_match(/^#{app_output % mode}$/, result.stdout)
        end
      end
    end

    step "clear out the libdir on the agents in preparation for the next test" do
      agents.each do |agent|
        on(agent, "rm -rf #{get_test_file_path(agent, agent_module_app_file)}/*")
      end
    end

  end

  all_tests_passed = true

ensure
  ##########################################################################################
  # Clean up all of the temp files created by this test.  It would be nice if this logic
  # could be handled outside of the test itself; I envision a stanza like this one appearing
  # in a very large number of the tests going forward unless it is handled by the framework.
  ##########################################################################################
  if all_tests_passed then
    all_hosts.each do |host|
      on(host, "rm -rf #{@host_test_tmp_dirs[host.name]}")
    end
  end
end