test_name "The source attribute"

step "Ensure the test environment is clean"
on agents, 'rm -f /tmp/source_file_test.txt'

step "when using a puppet:/// URI with a master/agent setup"
modulepath = nil
on master, puppet_master('--configprint modulepath') do
  modulepath = stdout.split(':')[0].chomp
end

result_file = "/tmp/#{$$}-result-file"
source_file = File.join(modulepath, 'source_test_module', 'files', 'source_file')
manifest = "/tmp/#{$$}-source-test.pp"

# Remove the SSL dir so we don't have cert issues
on master, "rm -rf `puppet master --configprint ssldir`"
on agents, "rm -rf `puppet agent --configprint ssldir`"

on master, "mkdir -p #{File.dirname(source_file)}"
on master, "echo 'the content is present' > #{source_file}"
on master, %Q[echo "file { '#{result_file}': source => 'puppet:///modules/source_test_module/source_file', ensure => present }" > #{manifest}]

with_master_running_on master, "--autosign true --manifest #{manifest} --dns_alt_names=\"puppet, $(hostname -s), $(hostname -f)\"" do
  run_agent_on agents, "--test --server #{master}", :acceptable_exit_codes => [2] do
    on agents, "cat #{result_file}" do
      assert_match(/the content is present/, stdout, "Result file not created")
    end
  end
end

# TODO: Add tests for puppet:// URIs with multi-master/agent setups.
# step "when using a puppet://$server/ URI with a master/agent setup"

step "Using a local file path"
on agents, "echo 'Yay, this is the local file.' > /tmp/local_source_file_test.txt"
manifest = "file { '/tmp/source_file_test.txt': source => '/tmp/local_source_file_test.txt', ensure => present }"

apply_manifest_on agents, manifest
agents.each do |host|
  on host, "cat /tmp/source_file_test.txt" do
    assert_match(/Yay, this is the local file./, stdout, "FIRST: File contents not matched on #{host}")
  end
end

step "Ensure the test environment is clean"
on agents, 'rm -f /tmp/source_file_test.txt'

step "Using a puppet:/// URI with puppet apply"

on agents, puppet_agent("--configprint modulepath") do
  modulepath = stdout.split(':')[0]
  modulepath = modulepath.chomp
  on agents, "mkdir -p #{modulepath}/test_module/files"
  #on agents, "echo 'Yay, this is the puppet:/// file.' > #{modulepath}/test_module/files/test_file.txt"
  on agents, "echo 'Yay, this is the puppetfile.' > #{modulepath}/test_module/files/test_file.txt"
end

on agents, %q{echo "file { '/tmp/source_file_test.txt': source => 'puppet:///modules/test_module/test_file.txt', ensure => present }" > /tmp/source_test_manifest.pp}
on agents, puppet_apply("/tmp/source_test_manifest.pp")

agents.each do |host|
  on host, "cat /tmp/source_file_test.txt" do
    assert_match(/Yay, this is the puppetfile./, stdout, "SECOND: File contents not matched on #{host}")
  end
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
