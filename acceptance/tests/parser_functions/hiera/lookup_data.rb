test_name "Lookup data using the hiera parser function" do
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
         file { '#{confdir}/puppet.conf':
          ensure  => file,
          content => '
        [user]
        environment = production
        [main]
        codedir = #{codedir}
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
          mode => "0640",
        }
         file { '#{testdir}/hieradata/global.yaml':
          ensure  => file,
          content => "---
            port: 8080
          ",
          mode => "0640",
        }
         file {
          '#{codedir}/environments/production/modules/apache':;
          '#{codedir}/environments/production/modules/apache/manifests':;
        }
         file { '#{codedir}/environments/production/modules/apache/manifests/init.pp':
          ensure => file,
          content => '
            class apache {
              $port = hiera("port")
               notify { "port from hiera":
                message => "apache server port: ${port}"
              }
            }',
          mode => "0640",
        }
         file { '#{codedir}/environments/production/manifests/site.pp':
          ensure => file,
          content => "
            node default {
              include apache
            }",
          mode => "0640",
        }
      PP
    end

    step "Try to lookup string data" do
      on(agent, puppet("apply",
                       "#{codedir}/environments/production/manifests/site.pp",
                       confdir: confdir), acceptable_exit_codes: [0, 2])

      assert_match("apache server port: 8080", stdout)
    end
  end
end
