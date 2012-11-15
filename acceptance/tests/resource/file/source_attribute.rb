test_name "The source attribute"

targets = {}

agents.each do |agent|
  targets[agent] = agent.tmpfile('source_file_test')

  step "Ensure the test environment is clean"
  on agent, "rm -f #{targets[agent]}"
end

step "when using a puppet:/// URI with a master/agent setup"
modulepath = nil
on master, puppet_master('--configprint modulepath') do
  modulepath = stdout.split(':')[0].chomp
end

# This is unpleasant.  Because the manifest file must specify an absolute
# path for the source property of the file resource, and because that
# absolute path can't be the same on Windows as it is on unix, we are
# basically forced to have two separate manifest files.  This might be
# cleaner if it were separated into two tests, but since the actual
# functionality that we are testing is the same I decided to keep it here
# even though it's ugly.
windows_source_file = File.join(modulepath, 'source_test_module', 'files', 'windows_source_file')
windows_manifest = "/tmp/#{$$}-windows-source-test.pp"
windows_result_file = "C:/windows/temp/#{$$}-windows-result-file"

posix_source_file = File.join(modulepath, 'source_test_module', 'files', 'posix_source_file')
posix_manifest = "/tmp/#{$$}-posix-source-test.pp"
posix_result_file = "/tmp/#{$$}-posix-result-file"

# Remove the SSL dir so we don't have cert issues
on master, "rm -rf `puppet master --configprint ssldir`"
on agents, "rm -rf `puppet agent --configprint ssldir`"

on master, "mkdir -p #{File.dirname(windows_source_file)}"
on master, "echo 'the content is present' > #{windows_source_file}"
on master, "mkdir -p #{File.dirname(posix_source_file)}"
on master, "echo 'the content is present' > #{posix_source_file}"

on master, %Q[echo "file { '#{windows_result_file}': source => 'puppet:///modules/source_test_module/windows_source_file', ensure => present }" > #{windows_manifest}]
on master, %Q[echo "file { '#{posix_result_file}': source => 'puppet:///modules/source_test_module/posix_source_file', ensure => present }" > #{posix_manifest}]

# See disgusted comments above... running master once with the windows manifest
# and then once with the posix manifest.  Could potentially get around this by
# creating a manifest with nodes or by moving the windows bits into a separate
# test.
with_master_running_on master, "--autosign true --manifest #{windows_manifest} --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\"" do
  agents.each do |agent|
    next unless agent['platform'].include?('windows')
    run_agent_on agent, "--test --server #{master}", :acceptable_exit_codes => [2] do
      on agent, "cat #{windows_result_file}" do
        assert_match(/the content is present/, stdout, "Result file not created")
      end
    end
  end
end

  #run_agent_on agents, "--test --server #{master}", :acceptable_exit_codes => [2] do
  #  on agents, "cat #{result_file}" do
  #    assert_match(/the content is present/, stdout, "Result file not created")
  #  end
  #end

with_master_running_on master, "--autosign true --manifest #{posix_manifest} --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\"" do
  agents.each do |agent|
    next if agent['platform'].include?('windows')
    run_agent_on agent, "--test --server #{master}", :acceptable_exit_codes => [2] do
      on agent, "cat #{posix_result_file}" do
        assert_match(/the content is present/, stdout, "Result file not created")
      end
    end
  end
end


# TODO: Add tests for puppet:// URIs with multi-master/agent setups.
# step "when using a puppet://$server/ URI with a master/agent setup"

agents.each do |agent|
  step "Using a local file path"
  source = agent.tmpfile('local_source_file_test')
  on agent, "echo 'Yay, this is the local file.' > #{source}"

  manifest = "file { '#{targets[agent]}': source => '#{source}', ensure => present }"
  apply_manifest_on agent, manifest, :trace => true
  on agent, "cat #{targets[agent]}" do
    assert_match(/Yay, this is the local file./, stdout, "FIRST: File contents not matched on #{agent}")
  end

  step "Ensure the test environment is clean"
  on agent, "rm -f #{targets[agent]}"

  step "Using a puppet:/// URI with puppet apply"
  on agent, puppet_agent("--configprint modulepath") do
    modulepath = agent.path_split(stdout)[0]
    modulepath = modulepath.chomp
    on agent, "mkdir -p '#{modulepath}/test_module/files'"
    #on agent, "echo 'Yay, this is the puppet:/// file.' > #{modulepath}/test_module/files/test_file.txt"
    on agent, "echo 'Yay, this is the puppetfile.' > '#{modulepath}/test_module/files/test_file.txt'"
  end

  manifest = "file { '#{targets[agent]}': source => 'puppet:///modules/test_module/test_file.txt', ensure => present }"
  apply_manifest_on agent, manifest, :trace => true

  on agent, "cat #{targets[agent]}" do
    assert_match(/Yay, this is the puppetfile./, stdout, "SECOND: File contents not matched on #{agent}")
  end

  step "Cleanup"
  on agent, "rm -f #{targets[agent]}; rm -rf #{source}"
end

# Oops. We (Jesse & Jacob) ended up writing this before realizing that you
# can't actually specify "source => 'http://...'".  However, we're leaving it
# here, since there have been feature requests to support doing this.
# -- Mon, 07 Mar 2011 16:12:56 -0800
#
#step "Ensure the test environment is clean"
#on agents, 'rm -f /tmp/source_file_test.txt'
#
#step "when using an http:// file path"
#
#File.open '/tmp/puppet-acceptance-webrick-script.rb', 'w' do |file|
#  file.puts %q{#!/usr/bin/env ruby
#
#require 'webrick'
#
#class Simple < WEBrick::HTTPServlet::AbstractServlet
#  def do_GET(request, response)
#    status, content_type, body = do_stuff_with(request)
#
#    response.status = status
#    response['Content-Type'] = content_type
#    response.body = body
#  end
#
#  def do_stuff_with(request)
#    return 200, "text/plain", "you got a page"
#  end
#end
#
#class SimpleTwo < WEBrick::HTTPServlet::AbstractServlet
#  def do_GET(request, response)
#    status, content_type, body = do_stuff_with(request)
#
#    response.status = status
#    response['Content-Type'] = content_type
#    response.body = body
#  end
#
#  def do_stuff_with(request)
#    return 200, "text/plain", "you got a different page"
#  end
#end
#
#server = WEBrick::HTTPServer.new :Port => 8081
#trap "INT"  do server.shutdown end
#trap "TERM" do server.shutdown end
#trap "QUIT" do server.shutdown end
#
#server.mount "/", SimpleTwo
#server.mount "/foo.txt", Simple
#server.start
#}
#end
#
#scp_to master, '/tmp/puppet-acceptance-webrick-script.rb', '/tmp'
#on master, "chmod +x /tmp/puppet-acceptance-webrick-script.rb && /tmp/puppet-acceptance-webrick-script.rb &"
#
#manifest = "file { '/tmp/source_file_test.txt': source => 'http://#{master}:8081/foo.txt', ensure => present }"
#
#apply_manifest_on agents, manifest
#
#on agents, 'test "$(cat /tmp/source_file_test.txt)" = "you got a page"'
#
#on master, "killall puppet-acceptance-webrick-script.rb"
