require "puppet/acceptance/puppet_type_test_tools.rb"
test_name "Lookup data using the hiera_hash parser function" do
  extend Puppet::Acceptance::PuppetTypeTestTools
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
          '#{testdir}/hieradata':;
          '#{confdir}':;
          '#{codedir}':;
          '#{codedir}/environments':;
          '#{codedir}/environments/production':;
          '#{codedir}/environments/production/manifests':;
          '#{codedir}/environments/production/modules':;
        }

        file { '#{testdir}/puppet/puppet.conf':
          ensure  => file,
          content => "
        [user]
        environment = production
        [main]
        environmentpath = #{codedir}/environments
        hiera_config = #{testdir}/hiera.yaml
        ";
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
            database_user:
              name: postgres
              uid: 500
              gid: 500
          ",
          mode => "0640";
        }

        file { '#{testdir}/hieradata/production.yaml':
          ensure  => file,
          content => "---
            database_user:
              shell: '/bin/bash'
          ",
          mode => "0640";
        }

        file {
          '#{codedir}/environments/production/modules/ntp/':;
          '#{codedir}/environments/production/modules/ntp/manifests':;
        }

        file { '#{codedir}/environments/production/modules/ntp/manifests/init.pp':
          ensure => file,
          content => 'class ntp {
            $database_user = hiera_hash("database_user")

            notify { "the database user":
              message => "name: ${database_user["name"]} shell: ${database_user["shell"]}"
            }
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

    step "Try to lookup hash data" do
      on(agent, puppet("apply",
                       "#{codedir}/environments/production/manifests/site.pp",
                       confdir: confdir)) do |result|
        assert_match("name: postgres shell: /bin/bash", result.stdout)
      end
    end
  end
end
