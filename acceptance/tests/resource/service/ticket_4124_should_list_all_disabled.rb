test_name "#4124: should list all disabled services on Redhat/CentOS"
step "Validate disabled services agreement ralsh vs. OS service count"
# This will remotely exec:
# ticket_4124_should_list_all_disabled.sh

hosts.each do |host|
  if host['platform'] =~ /el-5/
    run_script_on(host, File.join(File.dirname(__FILE__), 'ticket_4124_should_list_all_disabled.sh'))
  else
    skip_test "Test not supported on this plaform"
  end
end
