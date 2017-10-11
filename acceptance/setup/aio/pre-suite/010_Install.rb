require 'puppet/acceptance/common_utils'
require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install puppet-agent..." do
  opts = {
    :puppet_collection    => 'PC1',
    :puppet_agent_sha     => ENV['SHA'],
    # SUITE_VERSION is necessary for Beaker to build a package download
    # url which is built upon a `git describe` for a SHA.
    # Beaker currently cannot find or calculate this value based on
    # the SHA, and thus it must be passed at invocation time.
    # The one exception is when SHA is a tag like `1.8.0` and
    # SUITE_VERSION will be equivalent.
    # RE-8333 may make this unnecessary in the future
    :puppet_agent_version => ENV['SUITE_VERSION'] || ENV['SHA']
  }
  agents.each do |agent|
    next if agent == master # Avoid SERVER-528

    # Update openssl package on rhel7 if linking against system openssl
    use_system_openssl = ENV['USE_SYSTEM_OPENSSL']
    if use_system_openssl &&  agent[:platform].match(/(?:el-7|redhat-7)/)
      rhel7_openssl_version = ENV["RHEL7_OPENSSL_VERSION"]
      if rhel7_openssl_version.to_s.empty?
        # Fallback to some default is none is provided
        rhel7_openssl_version = "openssl-1.0.1e-51.el7_2.4.x86_64"
      end
      on(agent, "yum -y install " +  rhel7_openssl_version)
    else
      step "Skipping upgrade of openssl package... (" + agent[:platform] + ")"
    end

    install_puppet_agent_dev_repo_on(agent, opts)
  end
end

MASTER_PACKAGES = {
  :redhat => [
    'puppetserver',
  ],
  :debian => [
    'puppetserver',
  ],
}

step "Install puppetserver..." do
  if master[:hypervisor] == 'ec2'
    if master[:platform].match(/(?:el|centos|oracle|redhat|scientific)/)
      # An EC2 master instance does not have access to puppetlabs.net for getting
      # dev repos.
      #
      # We will install the appropriate repo to satisfy the puppetserver requirement
      # and then upgrade puppet-agent with the targeted SHA package afterwards.
      #
      # Currently, only an `el` master is supported for this operation.
      if ENV['SERVER_VERSION']
        variant, version = master['platform'].to_array
        if ENV['SERVER_VERSION'].to_i < 5
          logger.info "EC2 master found: Installing nightly build of puppet-agent repo to satisfy puppetserver dependency."
          on(master, "rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-#{version}.noarch.rpm")
        else
          logger.info "EC2 master found: Installing nightly build of puppet-agent repo to satisfy puppetserver dependency."
          on(master, "rpm -Uvh https://yum.puppetlabs.com/puppet5-release-el-#{version}.noarch.rpm")
        end
      else
        logger.info "EC2 master found: Installing nightly build of puppet-agent repo to satisfy puppetserver dependency."
        install_repos_on(master, 'puppet-agent', 'nightly', 'repo-configs')
        install_repos_on(master, 'puppetserver', 'nightly', 'repo-configs')
      end

      master.install_package('puppetserver')

      logger.info "EC2 master found: Installing #{ENV['SHA']} build of puppet-agent."
      # Upgrade installed puppet-agent with targeted SHA.
      opts = {
        :puppet_collection => 'PC1',
        :puppet_agent_sha => ENV['SHA'],
        :puppet_agent_version => ENV['SUITE_VERSION'] || ENV['SHA'] ,
        :dev_builds_url => "http://builds.delivery.puppetlabs.net"
      }

      copy_dir_local = File.join('tmp', 'repo_configs', master['platform'])
      release_path_end, release_file = master.puppet_agent_dev_package_info( opts[:puppet_collection], opts[:puppet_agent_version], opts)
      release_path = "#{opts[:dev_builds_url]}/puppet-agent/#{opts[:puppet_agent_sha]}/repos/"
      release_path << release_path_end
      fetch_http_file(release_path, release_file, copy_dir_local)
      scp_to master, File.join(copy_dir_local, release_file), master.external_copy_base
      on master, "rpm -Uvh #{File.join(master.external_copy_base, release_file)} --oldpackage --force"
    else
      fail_test("EC2 master found, but it was not an `el` host: The specified `puppet-agent` build (#{ENV['SHA']}) cannot be installed.")
    end
  else
    if ENV['SERVER_VERSION'].nil? || ENV['SERVER_VERSION'] == 'latest'
      server_version = 'latest'
      server_download_url = "http://nightlies.puppet.com"
    else
      server_version = ENV['SERVER_VERSION']
      server_download_url = "http://builds.delivery.puppetlabs.net"
    end
    install_puppetlabs_dev_repo(master, 'puppetserver', server_version, nil, :dev_builds_url => server_download_url)

    # Bump version of openssl on rhel7 platforms
    use_system_openssl = ENV['USE_SYSTEM_OPENSSL']
    if use_system_openssl && master[:platform].match(/(?:el-7|redhat-7)/)
      rhel7_openssl_version = ENV['RHEL7_OPENSSL_VERSION']
      if rhel7_openssl_version.to_s.empty?
        # Fallback to some default is none is provided
        rhel7_openssl_version = "openssl-1.0.1e-51.el7_2.4.x86_64"
      end
      on(master, "yum -y install " +  rhel7_openssl_version)
    else
      step "Skipping upgrade of openssl package... (" + master[:platform] + ")"
    end

    install_puppetlabs_dev_repo(master, 'puppet-agent', ENV['SHA'])
    master.install_package('puppetserver')
  end
end

# make sure install is sane, beaker has already added puppet and ruby
# to PATH in ~/.ssh/environment
agents.each do |agent|
  on agent, puppet('--version')
  ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
  on agent, "#{ruby} --version"
end

# Get a rough estimate of clock skew among hosts
times = []
hosts.each do |host|
  ruby = Puppet::Acceptance::CommandUtils.ruby_command(host)
  on(host, "#{ruby} -e 'puts Time.now.strftime(\"%Y-%m-%d %T.%L %z\")'") do |result|
    times << result.stdout.chomp
  end
end
times.map! do |time|
  (Time.strptime(time, "%Y-%m-%d %T.%L %z").to_f * 1000.0).to_i
end
diff = times.max - times.min
if diff < 60000
  logger.info "Host times vary #{diff} ms"
else
  logger.warn "Host times vary #{diff} ms, tests may fail"
end

configure_gem_mirror(hosts)


step "Enable FIPS on agent hosts..." do

 # There might be a better way to do some things below but till then...
 # The TODO's need to be followed up

  agents.each do |agent|
    next if agent == master # Only on agents.

    # Do this only on rhel7, rhel6, f24, f25
    use_system_openssl = ENV['USE_SYSTEM_OPENSSL']
    if use_system_openssl
      # Other platforms to come...
      next if !agent[:platform].match(/(?:el-7|redhat-7)/)

      # Step 1: Disable prelinking
      # TODO:: Handle cases where the /etc/sysconfig/prelink might exist
      on(agent, 'echo "PRELINKING=no" > /etc/sysconfig/prelink')
      # TODO: prelink is commented till we figure how to attempt executing
      # it so any failures do not cause this thing to exit
      # on(agent, "prelink -u -a")
 
      # Step 2: Install dracut-fips, dracut-fips-aesni
      on(agent, "yum -y install dracut-fips")
      on(agent, "yum -y install dracut-fips-aesni")

      # TODO:: Backup existing kernel image in case anything goes south..
      # Step 3: Run dracut to update system for fips. 
      on(agent, "dracut -v -f")


      # TODO:: Steps 4 and 5 need to be adjusted for rhel6, f24, f25
      # as the method of enabling FIPS are different on those platforms. 
      # Below works on rhel7
      
      # Step 4: Find out the device details (BLOCK ID) of boot partition
      # append enable fips and boot block id to kernel command line in grub file
      
      on(agent, 'boot_blkid=$(blkid `df /boot | grep "/dev" | awk \'BEGIN{ FS=" "}; {print $1}\'` | awk \'BEGIN{ FS=" "}; {print $2}\' | sed \'s/"//g\');\
                 fips_bootblk="fips=1 boot="$boot_blkid;\
                 grub_linux_cmdline=`grep -e "^GRUB_CMDLINE_LINUX" /etc/default/grub | sed "s/\"$/ $fips_bootblk\"/"`;\
                 grep -v GRUB_CMDLINE_LINUX /etc/default/grub > /etc/default/grub.bak;\
                 /bin/cp -rf /etc/default/grub.bak /etc/default/grub;\
                 sed -i "/GRUB_DISABLE_RECOVERY/i $grub_linux_cmdline" /etc/default/grub')


      # Step 5: Run grub2 mkconfig to make the changes take effect.
      on(agent, 'grub2-mkconfig -o /boot/grub2/grub.cfg')

      # Reboot is needed for the system to start in FIPS mode
      agent.reboot
      timeout = 30
      begin
        Timeout.timeout(timeout) do
          until agent.up?
            sleep 1
          end
        end
      rescue Timeout::Error => e
        raise "Agent did not come back up within #{timeout} seconds."
      end
      
      # TODO:
      # Ensure that agent is actually in fips mode by examining the contents of
      # /proc/sys/crypto/fips_enabled and that it is 1

      # Switch to using sha256 to work in fips mode.
      on agent, puppet('config set digest_algorithm sha256')
      
    end
  end
end
