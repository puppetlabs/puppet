test_name "#4124: should list all disabled services on Redhat/CentOS" do
  confine :to, :platform => /(el|centos|oracle|redhat|scientific)-5/
  tag 'audit:medium',
      'audit:integration' # Doesn't change the system it runs on

  step "Validate disabled services agreement ralsh vs. OS service count" do
    # This will remotely exec:
    # ticket_4124_should_list_all_disabled.sh

    agents.each do |agent|
      run_script_on(agent, File.join(File.dirname(__FILE__), 'ticket_4124_should_list_all_disabled.sh'))
    end
  end

end
