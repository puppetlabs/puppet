test_name "Install packages and repositories on target machines..." do
  on hosts, "rm -rf /root/*.repo; rm -rf /root/*.rpm"
  scp_to hosts, 'repos.tar', '/root'
  on hosts, "cd /root && tar -xvf repos.tar"
  on hosts, "mv /root/*.repo /etc/yum.repos.d"
  on hosts, "rpm -Uvh --force /root/*.rpm"
  hosts.each do |host|
    if host['roles'].include?('master')
      on host, "yum install -q -y puppet-server"
    end
    if host['roles'].include?('agent')
      on host, "yum install -q -y puppet"
    end
  end
end
