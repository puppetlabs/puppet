test_name 'Puppet User and Group' do
  hosts.each do |host|
    next if !host['roles'].include?('master')

    step "ensure puppet user and group added to master nodes" do
      on host, "getent group puppet || groupadd puppet"

      if host['platform'].include? 'solaris'
        useradd_opts = '-d /puppet -m -s /bin/sh -g puppet puppet'
      else
        useradd_opts = 'puppet -g puppet -G puppet'
      end

      on host, "getent passwd puppet || useradd #{useradd_opts}"
    end

  end
end
