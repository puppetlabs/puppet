test_name 'work arounds for bugs' do
  hosts.each do |host|
    next if host['platform'].include? 'windows'

    step "REVISIT: see #9862, this step should not be required for agents" do
      on host, "getent group puppet || groupadd puppet"

      if host['platform'].include? 'solaris'
        useradd_opts = '-d /puppet -m -s /bin/sh -g puppet puppet'
      else
        useradd_opts = 'puppet -g puppet -G puppet'
      end

      on host, "getent passwd puppet || useradd #{useradd_opts}"
    end

    step "REVISIT: Work around bug #5794 not creating reports as required" do
      on host, "mkdir -p /tmp/reports && chown puppet:puppet /tmp/reports"
    end
  end
end
