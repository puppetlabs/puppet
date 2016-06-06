test_name "#4124: should list all disabled services on Redhat/CentOS"
confine :to, :platform => /(el|centos|oracle|redhat|scientific)-5/

step "Validate disabled services agreement ralsh vs. OS service count"
# This will remotely exec:
# ticket_4124_should_list_all_disabled.sh

hosts.each do |host|
  run_script_on(host, File.join(File.dirname(__FILE__), 'ticket_4124_should_list_all_disabled.sh'))
end
