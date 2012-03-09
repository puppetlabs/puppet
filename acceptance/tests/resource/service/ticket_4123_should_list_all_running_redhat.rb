test_name "#4123: should list all running services on Redhat/CentOS"
step "Validate services running agreement ralsh vs. OS service count"
# This will remotely exec:
# ticket_4123_should_list_all_running_redhat.sh

hosts.each do |host|
  if host['platform'].include?('el-')
    run_script_on(host, File.join(File.dirname(__FILE__), 'ticket_4123_should_list_all_running_redhat.sh'))
  else
    skip_test "Test not supported on this plaform" 
  end
end
