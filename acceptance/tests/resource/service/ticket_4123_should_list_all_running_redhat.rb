test_name "#4123: should list all running services on Redhat/CentOS"
confine :to, :platform => /(el|centos|oracle|redhat|scientific)-5/
tag 'audit:medium',
    'audit:refactor',   # Use block style `test_run`
    'audit:integration' # Doesn't change the system it runs on

step "Validate services running agreement ralsh vs. OS service count"
# This will remotely exec:
# ticket_4123_should_list_all_running_redhat.sh

hosts.each do |host|
  run_script_on(host, File.join(File.dirname(__FILE__), 'ticket_4123_should_list_all_running_redhat.sh'))
end
