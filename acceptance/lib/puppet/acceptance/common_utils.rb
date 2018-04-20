module Puppet
  module Acceptance
    module CronUtils
      def clean(agent, o={})
        o = {:user => 'tstuser'}.merge(o)
        run_cron_on(agent, :remove, o[:user])
        apply_manifest_on(agent, %[user { '%s': ensure => absent, managehome => false }] % o[:user])
      end

      def setup(agent, o={})
        o = {:user => 'tstuser'}.merge(o)
        apply_manifest_on(agent, %[user { '%s': ensure => present, managehome => false }] % o[:user])
        apply_manifest_on(agent, %[case $operatingsystem {
                                     centos, redhat: {$cron = 'cronie'}
                                     solaris: { $cron = 'core-os' }
                                     default: {$cron ='cron'} }
                                     package {'cron': name=> $cron, ensure=>present, }])
      end
    end

    module CAUtils
      def clean_cert(host, cn, check = true)
        if host == master && master[:is_puppetserver]
            on master, puppet_resource("service", master['puppetservice'], "ensure=stopped")
        end

        on(host, puppet('cert', 'clean', cn), :acceptable_exit_codes => check ? [0] : [0, 24])
        if check
          assert_match(/remov.*Certificate.*#{cn}/i, stdout, "Should see a log message that certificate request was removed.")
          on(host, puppet('cert', 'list', '--all'))
          assert_no_match(/#{cn}/, stdout, "Should not see certificate in list anymore.")
        end
      end

      def clear_agent_ssl
        return if master.is_pe?
        step "All: Clear agent only ssl settings (do not clear master)"
        hosts.each do |host|
          next if host == master
          ssldir = on(host, puppet('agent --configprint ssldir')).stdout.chomp
          (host[:platform] =~ /cisco_nexus/) ? on(host, "rm -rf #{ssldir}") : on(host, host_command("rm -rf '#{ssldir}'"))
        end
      end

      def reset_agent_ssl(resign = true)
        return if master.is_pe?
        clear_agent_ssl

        hostname = master.execute('facter hostname')
        fqdn = master.execute('facter fqdn')

        step "Clear old agent certificates from master" do
          agents.each do |agent|
            next if agent == master && agent.is_using_passenger?
            agent_cn = on(agent, puppet('agent --configprint certname')).stdout.chomp
            clean_cert(master, agent_cn, false) if agent_cn
          end
        end

        if resign
          step "Master: Ensure the master is listening and autosigning"
          with_puppet_running_on(master,
                                  :master => {
                                    :dns_alt_names => "puppet,#{hostname},#{fqdn}",
                                    :autosign => true,
                                  }
                                ) do

            agents.each do |agent|
              next if agent == master && agent.is_using_passenger?
              step "Agents: Run agent --test once to obtain auto-signed cert" do
                on agent, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [0,2]
              end
            end
          end
        end
      end
    end

    module CommandUtils
      def ruby_command(host)
        "env PATH=\"#{host['privatebindir']}:${PATH}\" ruby"
      end
      module_function :ruby_command

      def gem_command(host, type='aio')
        if type == 'aio'
          if host['platform'] =~ /windows/
            "env PATH=\"#{host['privatebindir']}:${PATH}\" cmd /c gem"
          else
            "env PATH=\"#{host['privatebindir']}:${PATH}\" gem"
          end
        else
          on(host, 'which gem').stdout.chomp
        end
      end
      module_function :gem_command
    end
  end
end
