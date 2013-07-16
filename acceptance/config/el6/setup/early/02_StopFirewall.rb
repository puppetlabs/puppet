test_name "Stop firewall" do
  on hosts, puppet_resource('service', 'iptables', 'ensure=stopped')
end
