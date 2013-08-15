test_name 'Puppet User and Group' do
  hosts.each do |host|

    step "ensure puppet user and group added to all nodes because this is what the packages do" do
      on host, puppet("resource user puppet ensure=present")
      on host, puppet("resource group puppet ensure=present")
    end

  end
end
