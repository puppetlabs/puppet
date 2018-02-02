test_name "Stop firewall" do
  hosts.each do |host|
    case host['platform']
    when /debian/
      on host, 'iptables -F'
    when /fedora|el-7/
      on host, puppet('resource', 'service', 'firewalld', 'ensure=stopped')
    when /el-|centos/
      on host, puppet('resource', 'service', 'iptables', 'ensure=stopped')
    when /ubuntu/
      on host, puppet('resource', 'service', 'ufw', 'ensure=stopped')
    else
      logger.notify("Not sure how to clear firewall on #{host['platform']}")
    end
  end
end
