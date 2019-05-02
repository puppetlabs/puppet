test_name "Lookup data using the hiera_array parser function" do
  tag 'audit:medium',
      'audit:acceptance'

  agents.each do |agent|
    testdir = agent.tmpdir("hiera")
    confdir = "#{testdir}/puppet"
    codedir = "#{testdir}/code"

    step "Setup" do
      apply_manifest_on(agent, <<~PP, catch_failures: true)
        File {
          ensure => directory,
          mode => "0750",
        }
         file {
          '#{testdir}':;
          '#{confdir}':;
          '#{testdir}/hieradata':;
          '#{codedir}':;
          '#{codedir}/environments':;
          '#{codedir}/environments/production':;
          '#{codedir}/environments/production/manifests':;
          '#{codedir}/environments/production/modules':;
        }
         file { '#{testdir}/puppet/puppet.conf':
          ensure  => file,
          content => '
        [user]
        environment = production
        [main]
        environmentpath = #{codedir}/environments
        hiera_config = #{testdir}/hiera.yaml
        ',
        }
         file { '#{testdir}/hiera.yaml':
          ensure  => file,
          content => '---
            :backends:
              - "yaml"
            :logger: "console"
            :hierarchy:
              - "%{fqdn}"
              - "%{environment}"
              - "global"
            :yaml:
              :datadir: "#{testdir}/hieradata"
          ',
          mode => "0640";
        }
         file { '#{testdir}/hieradata/global.yaml':
          ensure  => file,
          content => "---
            port: '8080'
            ntpservers: ['global.ntp.puppetlabs.com']
          ",
          mode => "0640";
        }
         file { '#{testdir}/hieradata/production.yaml':
          ensure  => file,
          content => "---
            ntpservers: ['production.ntp.puppetlabs.com']
          ",
          mode => "0640";
        }
         file {
          '#{codedir}/environments/production/modules/ntp':;
          '#{codedir}/environments/production/modules/ntp/manifests':;
        }
         file { '#{codedir}/environments/production/modules/ntp/manifests/init.pp':
          ensure => file,
          content => '
            class ntp {
              $ntpservers = hiera_array("ntpservers")
               define print {
                $server = $name
                notify { "ntpserver ${server}": }
              }
               ntp::print { $ntpservers: }
            }',
          mode => "0640";
        }
         file { '#{codedir}/environments/production/manifests/site.pp':
          ensure => file,
          content => "
            node default {
              include ntp
            }",
          mode => "0640";
        }
      PP
    end

    step "Try to lookup array data" do
      on(agent, puppet("apply",
                       "#{codedir}/environments/production/manifests/site.pp",
                       confdir: confdir), acceptable_exit_codes: [0]) do |result|
        assert_match("ntpserver global.ntp.puppetlabs.com", result.stdout)
        assert_match("ntpserver production.ntp.puppetlabs.com", result.stdout)
      end
    end
  end
end
