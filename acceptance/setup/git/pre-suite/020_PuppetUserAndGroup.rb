test_name 'Puppet User and Group' do
  hosts.each do |host|

    step "making_sure puppet user and group added to all nodes because this is what the packages do" do
      on host, puppet("resource user puppet making_sure=present")
      on host, puppet("resource group puppet making_sure=present")
    end

  end
end
