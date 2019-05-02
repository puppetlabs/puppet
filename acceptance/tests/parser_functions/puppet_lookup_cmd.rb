test_name "Puppet Lookup Command" do
  tag 'audit:medium',
      'audit:acceptance'

  # doc:
  # https://puppet.com/docs/puppet/latest/hiera_automatic.html

  agents.each do |agent|
    @module_name = "puppet_lookup_command_test"

    @testroot = agent.tmpdir(@module_name.to_s)

    @coderoot = "#{@testroot}/code"
    @confdir = "#{@testroot}/puppet"

    @node1 = "node1.example.org"
    @node2 = "node2.example.org"

    @manifest = <<~MANIFEST
      File {
        ensure => directory,
        mode => "0755",
      }

      file {
        '#{@confdir}':;
        '#{@coderoot}':;
        '#{@coderoot}/hieradata':;
        '#{@coderoot}/environments':;

      ##### puppet.conf
        '#{@confdir}/puppet.conf' :
        ensure => file,
        mode => "0664",
        content => "[main]
      environmentpath = #{@coderoot}/environments
      hiera_config = #{@coderoot}/hiera.yaml
      ";

      ##### default environment, production
        '#{@coderoot}/environments/production':;
        '#{@coderoot}/environments/production/data':;
        '#{@coderoot}/environments/production/functions':;
        '#{@coderoot}/environments/production/functions/environment':;
        '#{@coderoot}/environments/production/lib':;
        '#{@coderoot}/environments/production/lib/puppet':;
        '#{@coderoot}/environments/production/lib/puppet/functions':;
        '#{@coderoot}/environments/production/lib/puppet/functions/environment':;
        '#{@coderoot}/environments/production/manifests':;
        '#{@coderoot}/environments/production/modules':;

      #   module mod1 hiera
        '#{@coderoot}/environments/production/modules/mod1':;
        '#{@coderoot}/environments/production/modules/mod1/manifests':;
        '#{@coderoot}/environments/production/modules/mod1/data':;
        '#{@coderoot}/environments/production/modules/mod1/functions':;
        '#{@coderoot}/environments/production/modules/mod1/lib':;
        '#{@coderoot}/environments/production/modules/mod1/lib/puppet':;
        '#{@coderoot}/environments/production/modules/mod1/lib/puppet/functions':;
        '#{@coderoot}/environments/production/modules/mod1/lib/puppet/functions/mod1':;

      #   module mod2 ruby function
        '#{@coderoot}/environments/production/modules/mod2':;
        '#{@coderoot}/environments/production/modules/mod2/manifests':;
        '#{@coderoot}/environments/production/modules/mod2/data':;
        '#{@coderoot}/environments/production/modules/mod2/functions':;
        '#{@coderoot}/environments/production/modules/mod2/lib':;
        '#{@coderoot}/environments/production/modules/mod2/lib/puppet':;
        '#{@coderoot}/environments/production/modules/mod2/lib/puppet/functions':;
        '#{@coderoot}/environments/production/modules/mod2/lib/puppet/functions/mod2':;

      #   module mod3 puppet function
        '#{@coderoot}/environments/production/modules/mod3':;
        '#{@coderoot}/environments/production/modules/mod3/manifests':;
        '#{@coderoot}/environments/production/modules/mod3/data':;
        '#{@coderoot}/environments/production/modules/mod3/functions':;
        '#{@coderoot}/environments/production/modules/mod3/not-lib':;
        '#{@coderoot}/environments/production/modules/mod3/not-lib/puppet':;
        '#{@coderoot}/environments/production/modules/mod3/not-lib/puppet/functions':;
        '#{@coderoot}/environments/production/modules/mod3/not-lib/puppet/functions/mod3':;

      #   module mod4 none
        '#{@coderoot}/environments/production/modules/mod4':;
        '#{@coderoot}/environments/production/modules/mod4/manifests':;
        '#{@coderoot}/environments/production/modules/mod4/data':;
        '#{@coderoot}/environments/production/modules/mod4/functions':;
        '#{@coderoot}/environments/production/modules/mod4/lib':;
        '#{@coderoot}/environments/production/modules/mod4/lib/puppet':;
        '#{@coderoot}/environments/production/modules/mod4/lib/puppet/functions':;
        '#{@coderoot}/environments/production/modules/mod4/lib/puppet/functions/mod4':;

      ##### env1 hiera
        '#{@coderoot}/environments/env1':;
        '#{@coderoot}/environments/env1/data':;
        '#{@coderoot}/environments/env1/functions':;
        '#{@coderoot}/environments/env1/functions/environment':;
        '#{@coderoot}/environments/env1/lib':;
        '#{@coderoot}/environments/env1/lib/puppet':;
        '#{@coderoot}/environments/env1/lib/puppet/functions':;
        '#{@coderoot}/environments/env1/lib/puppet/functions/environment':;
        '#{@coderoot}/environments/env1/manifests':;
        '#{@coderoot}/environments/env1/modules':;

      #   module mod1 hiera
        '#{@coderoot}/environments/env1/modules/mod1':;
        '#{@coderoot}/environments/env1/modules/mod1/manifests':;
        '#{@coderoot}/environments/env1/modules/mod1/data':;
        '#{@coderoot}/environments/env1/modules/mod1/functions':;
        '#{@coderoot}/environments/env1/modules/mod1/lib':;
        '#{@coderoot}/environments/env1/modules/mod1/lib/puppet':;
        '#{@coderoot}/environments/env1/modules/mod1/lib/puppet/functions':;
        '#{@coderoot}/environments/env1/modules/mod1/lib/puppet/functions/mod1':;

      #   module mod2 ruby function
        '#{@coderoot}/environments/env1/modules/mod2':;
        '#{@coderoot}/environments/env1/modules/mod2/manifests':;
        '#{@coderoot}/environments/env1/modules/mod2/data':;
        '#{@coderoot}/environments/env1/modules/mod2/functions':;
        '#{@coderoot}/environments/env1/modules/mod2/lib':;
        '#{@coderoot}/environments/env1/modules/mod2/lib/puppet':;
        '#{@coderoot}/environments/env1/modules/mod2/lib/puppet/functions':;
        '#{@coderoot}/environments/env1/modules/mod2/lib/puppet/functions/mod2':;

      #   module mod3 puppet function
        '#{@coderoot}/environments/env1/modules/mod3':;
        '#{@coderoot}/environments/env1/modules/mod3/manifests':;
        '#{@coderoot}/environments/env1/modules/mod3/data':;
        '#{@coderoot}/environments/env1/modules/mod3/functions':;
        '#{@coderoot}/environments/env1/modules/mod3/not-lib':;
        '#{@coderoot}/environments/env1/modules/mod3/not-lib/puppet':;
        '#{@coderoot}/environments/env1/modules/mod3/not-lib/puppet/functions':;
        '#{@coderoot}/environments/env1/modules/mod3/not-lib/puppet/functions/mod3':;

      #   module mod4 none
        '#{@coderoot}/environments/env1/modules/mod4':;
        '#{@coderoot}/environments/env1/modules/mod4/manifests':;
        '#{@coderoot}/environments/env1/modules/mod4/data':;
        '#{@coderoot}/environments/env1/modules/mod4/functions':;
        '#{@coderoot}/environments/env1/modules/mod4/lib':;
        '#{@coderoot}/environments/env1/modules/mod4/lib/puppet':;
        '#{@coderoot}/environments/env1/modules/mod4/lib/puppet/functions':;
        '#{@coderoot}/environments/env1/modules/mod4/lib/puppet/functions/mod4':;


      ##### env2 ruby function
        '#{@coderoot}/environments/env2':;
        '#{@coderoot}/environments/env2/data':;
        '#{@coderoot}/environments/env2/functions':;
        '#{@coderoot}/environments/env2/functions/environment':;
        '#{@coderoot}/environments/env2/lib':;
        '#{@coderoot}/environments/env2/lib/puppet':;
        '#{@coderoot}/environments/env2/lib/puppet/functions':;
        '#{@coderoot}/environments/env2/lib/puppet/functions/environment':;
        '#{@coderoot}/environments/env2/manifests':;
        '#{@coderoot}/environments/env2/modules':;

      #   module mod1 hiera
        '#{@coderoot}/environments/env2/modules/mod1':;
        '#{@coderoot}/environments/env2/modules/mod1/manifests':;
        '#{@coderoot}/environments/env2/modules/mod1/data':;
        '#{@coderoot}/environments/env2/modules/mod1/functions':;
        '#{@coderoot}/environments/env2/modules/mod1/lib':;
        '#{@coderoot}/environments/env2/modules/mod1/lib/puppet':;
        '#{@coderoot}/environments/env2/modules/mod1/lib/puppet/functions':;
        '#{@coderoot}/environments/env2/modules/mod1/lib/puppet/functions/mod1':;

      #   module mod2 ruby function
        '#{@coderoot}/environments/env2/modules/mod2':;
        '#{@coderoot}/environments/env2/modules/mod2/manifests':;
        '#{@coderoot}/environments/env2/modules/mod2/data':;
        '#{@coderoot}/environments/env2/modules/mod2/functions':;
        '#{@coderoot}/environments/env2/modules/mod2/lib':;
        '#{@coderoot}/environments/env2/modules/mod2/lib/puppet':;
        '#{@coderoot}/environments/env2/modules/mod2/lib/puppet/functions':;
        '#{@coderoot}/environments/env2/modules/mod2/lib/puppet/functions/mod2':;

      #   module mod3 puppet function
        '#{@coderoot}/environments/env2/modules/mod3':;
        '#{@coderoot}/environments/env2/modules/mod3/manifests':;
        '#{@coderoot}/environments/env2/modules/mod3/data':;
        '#{@coderoot}/environments/env2/modules/mod3/functions':;
        '#{@coderoot}/environments/env2/modules/mod3/not-lib':;
        '#{@coderoot}/environments/env2/modules/mod3/not-lib/puppet':;
        '#{@coderoot}/environments/env2/modules/mod3/not-lib/puppet/functions':;
        '#{@coderoot}/environments/env2/modules/mod3/not-lib/puppet/functions/mod3':;

      #   module mod4 none
        '#{@coderoot}/environments/env2/modules/mod4':;
        '#{@coderoot}/environments/env2/modules/mod4/manifests':;
        '#{@coderoot}/environments/env2/modules/mod4/data':;
        '#{@coderoot}/environments/env2/modules/mod4/functions':;
        '#{@coderoot}/environments/env2/modules/mod4/lib':;
        '#{@coderoot}/environments/env2/modules/mod4/lib/puppet':;
        '#{@coderoot}/environments/env2/modules/mod4/lib/puppet/functions':;
        '#{@coderoot}/environments/env2/modules/mod4/lib/puppet/functions/mod4':;


      ##### env3 puppet function
        '#{@coderoot}/environments/env3':;
        '#{@coderoot}/environments/env3/data':;
        '#{@coderoot}/environments/env3/functions':;
        '#{@coderoot}/environments/env3/functions/environment':;
        '#{@coderoot}/environments/env3/not-lib':;
        '#{@coderoot}/environments/env3/not-lib/puppet':;
        '#{@coderoot}/environments/env3/not-lib/puppet/functions':;
        '#{@coderoot}/environments/env3/not-lib/puppet/functions/environment':;
        '#{@coderoot}/environments/env3/manifests':;
        '#{@coderoot}/environments/env3/modules':;

      #   module mod1 hiera
        '#{@coderoot}/environments/env3/modules/mod1':;
        '#{@coderoot}/environments/env3/modules/mod1/manifests':;
        '#{@coderoot}/environments/env3/modules/mod1/data':;
        '#{@coderoot}/environments/env3/modules/mod1/functions':;
        '#{@coderoot}/environments/env3/modules/mod1/lib':;
        '#{@coderoot}/environments/env3/modules/mod1/lib/puppet':;
        '#{@coderoot}/environments/env3/modules/mod1/lib/puppet/functions':;
        '#{@coderoot}/environments/env3/modules/mod1/lib/puppet/functions/mod1':;

      #   module mod2 ruby function
        '#{@coderoot}/environments/env3/modules/mod2':;
        '#{@coderoot}/environments/env3/modules/mod2/manifests':;
        '#{@coderoot}/environments/env3/modules/mod2/data':;
        '#{@coderoot}/environments/env3/modules/mod2/functions':;
        '#{@coderoot}/environments/env3/modules/mod2/lib':;
        '#{@coderoot}/environments/env3/modules/mod2/lib/puppet':;
        '#{@coderoot}/environments/env3/modules/mod2/lib/puppet/functions':;
        '#{@coderoot}/environments/env3/modules/mod2/lib/puppet/functions/mod2':;

      #   module mod3 puppet function
        '#{@coderoot}/environments/env3/modules/mod3':;
        '#{@coderoot}/environments/env3/modules/mod3/manifests':;
        '#{@coderoot}/environments/env3/modules/mod3/data':;
        '#{@coderoot}/environments/env3/modules/mod3/functions':;
        '#{@coderoot}/environments/env3/modules/mod3/not-lib':;
        '#{@coderoot}/environments/env3/modules/mod3/not-lib/puppet':;
        '#{@coderoot}/environments/env3/modules/mod3/not-lib/puppet/functions':;
        '#{@coderoot}/environments/env3/modules/mod3/not-lib/puppet/functions/mod3':;

      #   module mod4 none
        '#{@coderoot}/environments/env3/modules/mod4':;
        '#{@coderoot}/environments/env3/modules/mod4/manifests':;
        '#{@coderoot}/environments/env3/modules/mod4/data':;
        '#{@coderoot}/environments/env3/modules/mod4/functions':;
        '#{@coderoot}/environments/env3/modules/mod4/lib':;
        '#{@coderoot}/environments/env3/modules/mod4/lib/puppet':;
        '#{@coderoot}/environments/env3/modules/mod4/lib/puppet/functions':;
        '#{@coderoot}/environments/env3/modules/mod4/lib/puppet/functions/mod4':;


      ##### env4 none
        '#{@coderoot}/environments/env4':;
        '#{@coderoot}/environments/env4/data':;
        '#{@coderoot}/environments/env4/functions':;
        '#{@coderoot}/environments/env4/functions/environment':;
        '#{@coderoot}/environments/env4/lib':;
        '#{@coderoot}/environments/env4/lib/puppet':;
        '#{@coderoot}/environments/env4/lib/puppet/functions':;
        '#{@coderoot}/environments/env4/lib/puppet/functions/environment':;
        '#{@coderoot}/environments/env4/manifests':;
        '#{@coderoot}/environments/env4/modules':;

      #   module mod1 hiera
        '#{@coderoot}/environments/env4/modules/mod1':;
        '#{@coderoot}/environments/env4/modules/mod1/manifests':;
        '#{@coderoot}/environments/env4/modules/mod1/data':;
        '#{@coderoot}/environments/env4/modules/mod1/functions':;
        '#{@coderoot}/environments/env4/modules/mod1/lib':;
        '#{@coderoot}/environments/env4/modules/mod1/lib/puppet':;
        '#{@coderoot}/environments/env4/modules/mod1/lib/puppet/functions':;
        '#{@coderoot}/environments/env4/modules/mod1/lib/puppet/functions/mod1':;

      #   module mod2 ruby function
        '#{@coderoot}/environments/env4/modules/mod2':;
        '#{@coderoot}/environments/env4/modules/mod2/manifests':;
        '#{@coderoot}/environments/env4/modules/mod2/data':;
        '#{@coderoot}/environments/env4/modules/mod2/functions':;
        '#{@coderoot}/environments/env4/modules/mod2/lib':;
        '#{@coderoot}/environments/env4/modules/mod2/lib/puppet':;
        '#{@coderoot}/environments/env4/modules/mod2/lib/puppet/functions':;
        '#{@coderoot}/environments/env4/modules/mod2/lib/puppet/functions/mod2':;

      #   module mod3 puppet function
        '#{@coderoot}/environments/env4/modules/mod3':;
        '#{@coderoot}/environments/env4/modules/mod3/manifests':;
        '#{@coderoot}/environments/env4/modules/mod3/data':;
        '#{@coderoot}/environments/env4/modules/mod3/functions':;
        '#{@coderoot}/environments/env4/modules/mod3/not-lib':;
        '#{@coderoot}/environments/env4/modules/mod3/not-lib/puppet':;
        '#{@coderoot}/environments/env4/modules/mod3/not-lib/puppet/functions':;
        '#{@coderoot}/environments/env4/modules/mod3/not-lib/puppet/functions/mod3':;

      #   module mod4 none
        '#{@coderoot}/environments/env4/modules/mod4':;
        '#{@coderoot}/environments/env4/modules/mod4/manifests':;
        '#{@coderoot}/environments/env4/modules/mod4/data':;
        '#{@coderoot}/environments/env4/modules/mod4/functions':;
        '#{@coderoot}/environments/env4/modules/mod4/lib':;
        '#{@coderoot}/environments/env4/modules/mod4/lib/puppet':;
        '#{@coderoot}/environments/env4/modules/mod4/lib/puppet/functions':;
        '#{@coderoot}/environments/env4/modules/mod4/lib/puppet/functions/mod4':;
      }

      ## Global data provider config (hiera)
      file { '#{@coderoot}/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        :backends:
          - "yaml"
        :logger: "console"
        :hierarchy:
          - "global"

        :yaml:
          :datadir: "#{@coderoot}/hieradata"
      ',
      }

      file { '#{@coderoot}/hieradata/global.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        global_key: "global-hiera provided value for key"
        another_global_key: "global-hiera provided value for key"
        mod1::global_key: "global-hiera provided value for key"
        mod2::global_key: "global-hiera provided value for key"
        mod3::global_key: "global-hiera provided value for key"
        mod4::global_key: "global-hiera provided value for key"
      ',
      }


      ## Evironment data provider configuration
      file { '#{@coderoot}/environments/production/environment.conf':
        ensure => file,
        mode => "0644",
        content => 'environment_timeout = 0
      ',
      }

      file { '#{@coderoot}/environments/env1/environment.conf':
        ensure => file,
        mode => "0644",
        content => 'environment_timeout = 0
      environment_data_provider = "hiera"
      ',
      }

      file { '#{@coderoot}/environments/env2/environment.conf':
        ensure => file,
        mode => "0644",
        content => 'environment_timeout = 0
      environment_data_provider = "function"
      ',
      }

      file { '#{@coderoot}/environments/env3/environment.conf':
        ensure => file,
        mode => "0644",
        content => 'environment_timeout = 0
      environment_data_provider = "function"
      ',
      }

      file { '#{@coderoot}/environments/env4/environment.conf':
        ensure => file,
        mode => "0644",
        content => 'environment_timeout = 0
      environment_data_provider = "none"
      ',
      }

      # Environment hiera data provider
      file { '#{@coderoot}/environments/production/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/production/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        global_key: "env-production hiera provided value"
        environment_key: "env-production hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env1/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env1/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        global_key: "env-env1 hiera provided value"
        environment_key: "env-env1 hiera provided value"
      ',
      }


      file { '#{@coderoot}/environments/env2/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env2/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        global_key: "env-env1 hiera provided value"
        environment_key: "env-env1 hiera provided value"
      ',
      }


      file { '#{@coderoot}/environments/env3/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env3/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        global_key: "env-env1 hiera provided value"
        environment_key: "env-env1 hiera provided value"
      ',
      }


      file { '#{@coderoot}/environments/env4/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env4/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        global_key: "env-env1 hiera provided value"
        environment_key: "env-env1 hiera provided value"
      ',
      }

      # Environment ruby function data provider
      file { '#{@coderoot}/environments/production/lib/puppet/functions/environment/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'environment::data') do
        def data()
          {
            'environment_key': 'env-production-ruby-function data() provided value',
            'global_key': 'env-production-ruby-function data () provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env1/lib/puppet/functions/environment/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'environment::data') do
        def data()
          {
            'environment_key' => 'env-env1-ruby-function data() provided value',
            'global_key' => 'env-env1-ruby-function data () provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env2/lib/puppet/functions/environment/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'environment::data') do
        def data()
          {
            'environment_key' => 'env-env2-ruby-function data() provided value',
            'global_key' => 'env-env2-ruby-function data () provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env3/not-lib/puppet/functions/environment/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'environment::data') do
        def data()
          {
            'environment_key' => 'env-env3-ruby-function data() provided value',
            'global_key' => 'env-env3-ruby-function data () provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env4/lib/puppet/functions/environment/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'environment::data') do
        def data()
          {
            'environment_key' => 'env-env4-ruby-function data() provided value',
            'global_key' => 'env-env4-ruby-function data () provided value',
          }
        end
      end
      ",
      }

      # Environment puppet function data provider
      file { '#{@coderoot}/environments/production/functions/environment/data.pp':
        ensure => file,
        mode => "0755",
        content => 'function environment::data() {
        {
          "environment_key" => "env-production-puppet-function data() provided value",
          "global_key" => "env-production-puppet-function data() provided value",
        }
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/functions/environment/data.pp':
        ensure => file,
        mode => "0755",
        content => 'function environment::data() {
        {
          "environment_key" => "env-env1-puppet-function data() provided value",
          "global_key" => "env-env1-puppet-function data() provided value",
        }
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/functions/environment/data.pp':
        ensure => file,
        mode => "0755",
        content => 'function environment::data() {
        {
          "environment_key" => "env-env2-puppet-function data() provided value",
          "global_key" => "env-env2-puppet-function data() provided value",
        }
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/functions/environment/data.pp':
        ensure => file,
        mode => "0755",
        content => 'function environment::data() {
        {
          "environment_key" => "env-env3-puppet-function data() provided value",
          "global_key" => "env-env3-puppet-function data() provided value",
        }
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/functions/environment/data.pp':
        ensure => file,
        mode => "0755",
        content => 'function environment::data() {
        {
          "environment_key" => "env-env4-puppet-function data() provided value",
          "global_key" => "env-env4-puppet-function data() provided value",
        }
      }
      ',
      }


      ## Module data provider configuration
      # Module hiera data provider
      file { '#{@coderoot}/environments/production/modules/mod1/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod1/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod1::module_key": "module-production-mod1-hiera provided value"
        "mod1::global_key": "module-production-mod1-hiera provided value"
        "environment_key": "module-production-mod1-hiera provided value"
        "global_key": "module-production-mod1-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod2/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod2/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod2::module_key": "module-production-mod2-hiera provided value"
        "mod2::global_key": "module-production-mod2-hiera provided value"
        "environment_key": "module-production-mod2-hiera provided value"
        "global_key": "module-production-mod2-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod3/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod3/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod3::module_key": "module-production-mod3-hiera provided value"
        "mod3::global_key": "module-production-mod3-hiera provided value"
        "environment_key": "module-production-mod3-hiera provided value"
        "global_key" => "module-production-mod3-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod4/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod4/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod4::module_key": "module-production-mod4-hiera provided value"
        "mod4::global_key": "module-production-mod4-hiera provided value"
        "environment_key": "module-production-mod4-hiera provided value"
        "global_key": "module-production-mod4-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod1/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod1/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod1::module_key": "module-env1-mod1-hiera provided value"
        "global_key": "module-env1-mod1-hiera provided value"
        "environment_key": "module-env1-mod1-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod2/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod2/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod2::module_key": "module-env1-mod2-hiera provided value"
        "global_key": "module-env1-mod2-hiera provided value"
        "environment_key": "module-env1-mod2-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod3/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod3/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod3::module_key": "module-env1-mod3-hiera provided value"
        "global_key": "module-env1-mod3-hiera provided value"
        "environment_key": "module-env1-mod3-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod4/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod4/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod4::module_key": "module-env1-mod4-hiera provided value"
        "global_key": "module-env1-mod4-hiera provided value"
        "environment_key": "module-env1-mod4-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod1/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod1/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod1::module_key": "module-env2-mod1-hiera provided value"
        "global_key": "module-env2-mod1-hiera provided value"
        "environment_key": "module-env2-mod1-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod2/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod2/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod2::module_key": "module-env2-mod2-hiera provided value"
        "global_key": "module-env2-mod2-hiera provided value"
        "environment_key": "module-env2-mod2-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod3/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod3/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod3::module_key": "module-env2-mod3-hiera provided value"
        "global_key": "module-env2-mod3-hiera provided value"
        "environment_key": "module-env2-mod3-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod4/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod4/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod4::module_key": "module-env2-mod4-hiera provided value"
        "global_key": "module-env2-mod4-hiera provided value"
        "environment_key": "module-env2-mod4-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod1/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod1/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod1::module_key": "module-env3-mod1-hiera provided value"
        "global_key": "module-env3-mod1-hiera provided value"
        "environment_key": "module-env3-mod1-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod2/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod2/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod2::module_key": "module-env3-mod2-hiera provided value"
        "global_key": "module-env3-mod2-hiera provided value"
        "environment_key": "module-env3-mod2-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod3/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod3/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod3::module_key": "module-env3-mod3-hiera provided value"
        "global_key": "module-env3-mod3-hiera provided value"
        "environment_key": "module-env3-mod3-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod4/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod4/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod4::module_key": "module-env3-mod4-hiera provided value"
        "global_key": "module-env3-mod4-hiera provided value"
        "environment_key": "module-env3-mod4-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod1/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod1/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod1::module_key": "module-env4-mod1-hiera provided value"
        "global_key": "module-env4-mod1-hiera provided value"
        "environment_key": "module-env4-mod1-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod2/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod2/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod2::module_key": "module-env4-mod2-hiera provided value"
        "global_key": "module-env4-mod2-hiera provided value"
        "environment_key": "module-env4-mod2-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod3/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod3/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod3::module_key": "module-env4-mod3-hiera provided value"
        "global_key": "module-env4-mod3-hiera provided value"
        "environment_key": "module-env4-mod3-hiera provided value"
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod4/hiera.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        version: 4
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod4/data/common.yaml':
        ensure => file,
        mode => "0644",
        content => '---
        "mod4::module_key": "module-env4-mod4-hiera provided value"
        "global_key": "module-env4-mod4-hiera provided value"
        "environment_key": "module-env4-mod4-hiera provided value"
      ',
      }

      # Module ruby function data provider
      file { '#{@coderoot}/environments/production/modules/mod1/lib/puppet/functions/mod1/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod1::data') do
        def data()
          {
            'mod1::module_key' => 'module-production-mod1-ruby-function provided value',
            'mod1::global_key' => 'module-production-mod1-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/production/modules/mod2/lib/puppet/functions/mod2/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod2::data') do
        def data()
          {
            'mod2::module_key' => 'module-production-mod2-ruby-function provided value',
            'mod2::global_key' => 'module-production-mod2-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/production/modules/mod3/not-lib/puppet/functions/mod3/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod3::data') do
        def data()
          {
            'mod3::module_key' => 'module-production-mod3-ruby-function provided value',
            'mod3::global_key' => 'module-production-mod3-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/production/modules/mod4/lib/puppet/functions/mod4/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod4::data') do
        def data()
          {
            'mod4::module_key' => 'module-production-mod4-ruby-function provided value',
            'mod4::global_key' => 'module-production-mod4-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env1/modules/mod1/lib/puppet/functions/mod1/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod1::data') do
        def data()
          {
            'mod1::module_key' => 'module-env1-mod1-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env1/modules/mod2/lib/puppet/functions/mod2/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod2::data') do
        def data()
          {
            'mod2::module_key' => 'module-env1-mod2-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env1/modules/mod3/not-lib/puppet/functions/mod3/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod3::data') do
        def data()
          {
            'mod3::module_key' => 'module-env1-mod3-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env1/modules/mod4/lib/puppet/functions/mod4/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod4::data') do
        def data()
          {
            'mod4::module_key' => 'module-env1-mod4-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env2/modules/mod1/lib/puppet/functions/mod1/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod1::data') do
        def data()
          {
            'mod1::module_key' => 'module-env2-mod1-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env2/modules/mod2/lib/puppet/functions/mod2/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod2::data') do
        def data()
          {
            'mod2::module_key' => 'module-env2-mod2-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env2/modules/mod3/not-lib/puppet/functions/mod3/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod3::data') do
        def data()
          {
            'mod3::module_key' => 'module-env2-mod3-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env2/modules/mod4/lib/puppet/functions/mod4/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod4::data') do
        def data()
          {
            'mod4::module_key' => 'module-env2-mod4-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env3/modules/mod1/lib/puppet/functions/mod1/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod1::data') do
        def data()
          {
            'mod1::module_key' => 'module-env3-mod1-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env3/modules/mod2/lib/puppet/functions/mod2/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod2::data') do
        def data()
          {
            'mod2::module_key' => 'module-env3-mod2-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env3/modules/mod3/not-lib/puppet/functions/mod3/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod3::data') do
        def data()
          {
            'mod3::module_key' => 'module-env3-mod3-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env3/modules/mod4/lib/puppet/functions/mod4/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod4::data') do
        def data()
          {
            'mod4::module_key' => 'module-env3-mod4-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env4/modules/mod1/lib/puppet/functions/mod1/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod1::data') do
        def data()
          {
            'mod1::module_key' => 'module-env4-mod1-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env4/modules/mod2/lib/puppet/functions/mod2/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod2::data') do
        def data()
          {
            'mod2::module_key' => 'module-env4-mod2-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env4/modules/mod3/not-lib/puppet/functions/mod3/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod3::data') do
        def data()
          {
            'mod3::module_key' => 'module-env4-mod3-ruby-function provided value',
          }
        end
      end
      ",
      }

      file { '#{@coderoot}/environments/env4/modules/mod4/lib/puppet/functions/mod4/data.rb':
        ensure => file,
        mode => "0644",
        content => "Puppet::Functions.create_function(:'mod4::data') do
        def data()
          {
            'mod4::module_key' => 'module-env4-mod4-ruby-function provided value',
          }
        end
      end
      ",
      }

      # Module puppet function data provider
      file {  '#{@coderoot}/environments/production/modules/mod1/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod1::data() {
        {
          'mod1::module_key' => 'module-production-mod1-puppet-function provided value',
          'mod1::global_key' => 'module-production-mod1-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/production/modules/mod2/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod2::data() {
        {
          'mod2::module_key' => 'module-production-mod2-puppet-function provided value',
          'mod2::global_key' => 'module-production-mod2-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/production/modules/mod3/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod3::data() {
        {
          'mod3::module_key' => 'module-production-mod3-puppet-function provided value',
          'mod3::global_key' => 'module-production-mod3-puppet-funtion provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/production/modules/mod4/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod4::data() {
        {
          'mod4::module_key' => 'module-production-mod4-puppet-function provided value',
          'mod4::global_key' => 'module-production-mod4-puppet-funtion provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env1/modules/mod1/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod1::data() {
        {
          'mod1::module_key' => 'module-env1-mod1-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env1/modules/mod2/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod2::data() {
        {
          'mod2::module_key' => 'module-env1-mod2-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env1/modules/mod3/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod3::data() {
        {
          'mod3::module_key' => 'module-env1-mod3-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env1/modules/mod4/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod4::data() {
        {
          'mod4::module_key' => 'module-env1-mod4-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env2/modules/mod1/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod1::data() {
        {
          'mod1::module_key' => 'module-env2-mod1-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env2/modules/mod2/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod2::data() {
        {
          'mod2::module_key' => 'module-env2-mod2-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env2/modules/mod3/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod3::data() {
        {
          'mod3::module_key' => 'module-env2-mod3-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env2/modules/mod4/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod4::data() {
        {
          'mod4::module_key' => 'module-env2-mod4-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env3/modules/mod1/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod1::data() {
        {
          'mod1::module_key' => 'module-env3-mod1-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env3/modules/mod2/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod2::data() {
        {
          'mod2::module_key' => 'module-env3-mod2-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env3/modules/mod3/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod3::data() {
        {
          'mod3::module_key' => 'module-env3-mod3-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env3/modules/mod4/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod4::data() {
        {
          'mod4::module_key' => 'module-env3-mod4-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env4/modules/mod1/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod1::data() {
        {
          'mod1::module_key' => 'module-env4-mod1-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env4/modules/mod2/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod2::data() {
        {
          'mod2::module_key' => 'module-env4-mod2-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env4/modules/mod3/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod3::data() {
        {
          'mod3::module_key' => 'module-env4-mod3-puppet-function provided value',
        }
      }
      ",
      }

      file {  '#{@coderoot}/environments/env4/modules/mod4/functions/data.pp':
        ensure => file,
        mode => "0644",
        content => "function mod4::data() {
        {
          'mod4::module_key' => 'module-env4-mod4-puppet-function provided value',
        }
      }
      ",
      }

      file { '#{@coderoot}/environments/production/manifests/site.pp':
        ensure => file,
        mode => "0644",
        content => "node default {
        include mod1
        include mod2
        include mod3
        include mod4
      }
      ",
      }

      file { '#{@coderoot}/environments/env1/manifests/site.pp':
        ensure => file,
        mode => "0644",
        content => "node default {
        include mod1
        include mod2
        include mod3
        include mod4
      }
      ",
      }

      file { '#{@coderoot}/environments/env2/manifests/site.pp':
        ensure => file,
        mode => "0644",
        content => "node default {
        include mod1
        include mod2
        include mod3
        include mod4
      }
      ",
      }

      file { '#{@coderoot}/environments/env3/manifests/site.pp':
        ensure => file,
        mode => "0644",
        content => "node default {
        include mod1
        include mod2
        include mod3
        include mod4
      }
      ",
      }

      file { '#{@coderoot}/environments/env4/manifests/site.pp':
        ensure => file,
        mode => "0644",
        content => "node default {
        include mod1
        include mod2
        include mod2
        include mod2
      }
      ",
      }

      file { '#{@coderoot}/environments/production/modules/mod1/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod1 {
        notice("hello from production-mod1")
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod2/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod2 {
        notice("hello from production-mod2")
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod3/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod3 {
        notice("hello from production-mod3")
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod4/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod4 {
        notice("hello from production-mod4")
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod1/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod1 {
        notice("hello from env1-mod1")
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod2/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod2 {
        notice("hello from env1-mod2")
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod3/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod3 {
        notice("hello from env1-mod3")
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod4/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod4 {
        notice("hello from env1-mod4")
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod1/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod1 {
        notice("hello from env2-mod1")
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod2/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod2 {
        notice("hello from env2-mod2")
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod3/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod3 {
        notice("hello from env2-mod3")
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod4/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod4 {
        notice("hello from env2-mod4")
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod1/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod1 {
        notice("hello from env3-mod1")
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod2/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod2 {
        notice("hello from env3-mod2")
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod3/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod3 {
        notice("hello from env3-mod3")
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod4/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod4 {
        notice("hello from env3-mod4")
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod1/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod1 {
        notice("hello from env4-mod1")
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod2/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod2 {
        notice("hello from env4-mod2")
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod3/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod3 {
        notice("hello from env4-mod3")
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod4/manifests/init.pp':
        ensure => file,
        mode => "0644",
        content => 'class mod4 {
        notice("hello from env4-mod4")
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod1/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod1",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "hiera"
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod2/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod2",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod3/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod3",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/production/modules/mod4/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod1",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "none"
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod1/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod1",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "hiera"
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod2/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod2",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod3/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod3",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env1/modules/mod4/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod4",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "none"
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod1/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod1",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "hiera"
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod2/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod2",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod3/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod3",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env2/modules/mod4/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod4",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "none"
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod1/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod1",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "hiera"
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod2/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod2",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod3/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod3",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env3/modules/mod4/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod4",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "none"
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod1/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod1",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "hiera"
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod2/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod2",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod3/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod3",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "function"
      }
      ',
      }

      file { '#{@coderoot}/environments/env4/modules/mod4/metadata.json':
        ensure => file,
        mode => "0644",
        content => '{
        "name": "tester-mod4",
        "version": "0.1.0",
        "author": "tester",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [],
        "data_provider": "none"
      }
      ',
      }
    MANIFEST

    @env1puppetconfmanifest = <<~MANI1
      file { '#{@confdir}/puppet.conf' :
        ensure => file,
        mode => "0664",
        content => "[main]
      environmentpath = #{@coderoot}/environments
      hiera_config = #{@coderoot}/hiera.yaml
      environment = env1
      ",
      }
    MANI1

    @env2puppetconfmanifest = <<~MANI2
      file { '#{@confdir}/puppet.conf' :
        ensure => file,
        mode => "0664",
        content => "[main]
      environmentpath = #{@coderoot}/environments
      hiera_config = #{@coderoot}/hiera.yaml
      environment = env2
      ",
      }
    MANI2

    @env3puppetconfmanifest = <<~MANI3
      file { '#{@confdir}/puppet.conf' :
        ensure => file,
        mode => "0664",
        content => "[main]
      environmentpath = #{@coderoot}/environments
      hiera_config = #{@coderoot}/hiera.yaml
      environment = env3
      ",
      }
    MANI3

    @env4puppetconfmanifest = <<~MANI4
      file { '#{@confdir}/puppet.conf' :
        ensure => file,
        mode => "0664",
        content => "[main]
      environmentpath = #{@coderoot}/environments
      hiera_config = #{@coderoot}/hiera.yaml
      environment = env4
      ",
      }
    MANI4

    ## enc
    ##
    ## This script does not work on windows. The emitted yaml throws an error
    ## when the indirector tries to parse it.
    ##
    ## Error: Could not run: Could not load external node results for node1.example.org: undefined method `inject' for #<String:0x0000000005041b40>
    ## Did you mean?  inspect
    ##
    @encmanifest = <<~MANIENC
      if $facts['os']['family'] == 'windows' {
        $enc_exe = 'enc.bat'
        file { "#{@coderoot}/$enc_exe" :
          ensure => file,
          mode => "0755",
          content => "@echo off\r\n\\"C:/Program Files/Puppet Labs/Puppet/puppet/bin/ruby.exe\\" \\"#{@coderoot}/enc.rb\\" %1",
        }
      }
      else {
        $enc_exe = 'enc.rb'
      }
      file { '#{@coderoot}/enc.rb' :
        ensure => file,
        mode => "0755",
        content => "#!#{agent['privatebindir']}/ruby
      nodename = ARGV.shift
      node2env = {
        '#{@node1}' => \\\"---\\\\n  environment: env2\\\\n\\\",
        '#{@node2}' => \\\"---\\\\n  environment: env3\\\\n\\\",
      }
      puts (\\\"\#{node2env[nodename]}\\\" ||'')
      ",
      }
      file { '#{@confdir}/puppet.conf' :
        ensure => file,
        mode => "0664",
        content => "[master]
      codedir = #{@coderoot}
      node_terminus = exec
      external_nodes = #{@coderoot}/$enc_exe
      [main]
      environmentpath = #{@coderoot}/environments
      hiera_config = #{@coderoot}/hiera.yaml
      ",
      }
    MANIENC

    #### BEGIN TESTS
    step "apply main manifest" do
      apply_manifest_on(agent, @manifest, catch_failures: true)
    end

    step "global_key" do
      rg = on(agent, puppet("lookup", "global_key", confdir: @confdir))
      result = rg.stdout
      assert_match(
        /global-hiera/,
        result,
        "global_key lookup failed, expected 'global-hiera'"
      )
    end

    step "production environment_key not provided" do
      on(agent, puppet("lookup", "enviroment_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "environment_key from environment env1" do
      re1 = on(agent, puppet("lookup", "--environment env1", "environment_key", confdir: @confdir))
      result = re1.stdout
      assert_match(
        /env-env1 hiera/,
        result,
        "env1 environment_key lookup failed, expected 'env-env1 hiera'"
      )
    end

    step "environment_key from environment env2" do
      re2 = on(agent, puppet("lookup", "--environment env2", "environment_key", confdir: @confdir))
      result = re2.stdout
      assert_match(
        /env-env2-ruby-function/,
        result,
        "env2 environment_key lookup failed, expected 'env-env2-puppet-function'"
      )
    end

    step "environment_key from environment env3" do
      re3 = on(agent, puppet("lookup", "--environment env3", "environment_key", confdir: @confdir))
      result = re3.stdout
      assert_match(
        /env-env3-puppet-function/,
        result,
        "env3 environment_key lookup failed, expected 'env-env2-ruby-function data() provided value'"
      )
    end

    step "environment_key from environment env4" do
      on(agent, puppet("lookup", "--environment env4", "environment_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "production mod1 module_key" do
      repm1 = on(agent, puppet("lookup", "mod1::module_key", confdir: @confdir))
      result = repm1.stdout
      assert_match(
        /module-production-mod1-hiera/,
        result,
        "production mod1 module_key lookup failed, expected 'module-production-mod1-hiera'"
      )
    end

    step "production mod2 module_key" do
      repm2 = on(agent, puppet("lookup", "mod2::module_key", confdir: @confdir))
      result = repm2.stdout
      assert_match(
        /module-production-mod2-ruby-function/,
        result,
        "production mod2 module_key lookup failed, expected 'module-production-mod2-ruby-function'"
      )
    end

    step "production mod3 module_key" do
      repm3 = on(agent, puppet("lookup", "mod3::module_key", confdir: @confdir))
      result = repm3.stdout
      assert_match(
        /module-production-mod3-puppet-function/,
        result,
        "production mod3 module_key lookup failed, expected 'module-production-mod3-puppet-function'"
      )
    end

    step "production mod4 module_key" do
      on(agent, puppet("lookup", "mod4::module_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "env1 mod1 module_key" do
      re1m1 = on(agent, puppet("lookup", "--environment env1", "mod1::module_key", confdir: @confdir))
      result = re1m1.stdout
      assert_match(
        /module-env1-mod1-hiera/,
        result,
        "env1 mod1 module_key lookup failed, expected 'module-env1-mod1-hiera'"
      )
    end

    step "env1 mod2 module_key" do
      re1m2 = on(agent, puppet("lookup", "--environment env1", "mod2::module_key", confdir: @confdir))
      result = re1m2.stdout
      assert_match(
        /module-env1-mod2-ruby-function/,
        result,
        "env1 mod2 module_key lookup failed, expected 'module-env1-mod2-ruby-function'"
      )
    end

    step "env1 mod3 module_key" do
      re1m3 = on(agent, puppet("lookup", "--environment env1", "mod3::module_key", confdir: @confdir))
      result = re1m3.stdout
      assert_match(
        /module-env1-mod3-puppet-function/,
        result,
        "env1 mod3 module_key lookup failed, expected 'module-env1-mod3-puppet-function'"
      )
    end

    step "env1 mod4 module_key" do
      on(agent, puppet("lookup", "--environment env1", "mod4::module_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "env2 mod1 module_key" do
      re2m1 = on(agent, puppet("lookup", "--environment env2", "mod1::module_key", confdir: @confdir))
      result = re2m1.stdout
      assert_match(
        /module-env2-mod1-hiera/,
        result,
        "env2 mod1 module_key lookup failed, expected 'module-env2-mod1-hiera'"
      )
    end

    step "env2 mod2 module_key" do
      re2m2 = on(agent, puppet("lookup", "--environment env2", "mod2::module_key", confdir: @confdir))
      result = re2m2.stdout
      assert_match(
        /module-env2-mod2-ruby-function/,
        result,
        "env2 mod2 module_key lookup failed, expected 'module-env2-mod2-ruby-function'"
      )
    end

    step "env2 mod3 module_key" do
      re2m3 = on(agent, puppet("lookup", "--environment env2", "mod3::module_key", confdir: @confdir))
      result = re2m3.stdout
      assert_match(
        /module-env2-mod3-puppet-function/,
        result,
        "env2 mod3 module_key lookup failed, expected 'module-env2-mod3-puppet-function'"
      )
    end

    step "env2 mod4 module_key" do
      on(agent, puppet("lookup", "--environment env2", "mod4::module_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "env3 mod1 module_key" do
      re3m1 = on(agent, puppet("lookup", "--environment env3", "mod1::module_key", confdir: @confdir))
      result = re3m1.stdout
      assert_match(
        /module-env3-mod1-hiera/,
        result,
        "env3 mod1 module_key lookup failed, expected 'module-env3-mod1-hiera'"
      )
    end

    step "env3 mod2 module_key" do
      re3m2 = on(agent, puppet("lookup", "--environment env3", "mod2::module_key", confdir: @confdir))
      result = re3m2.stdout
      assert_match(
        /module-env3-mod2-ruby-function/,
        result,
        "env3 mod2 module_key lookup failed, expected 'module-env3-mod2-ruby-function'"
      )
    end

    step "env3 mod3 module_key" do
      re3m3 = on(agent, puppet("lookup", "--environment env3", "mod3::module_key", confdir: @confdir))
      result = re3m3.stdout
      assert_match(
        /module-env3-mod3-puppet-function/,
        result,
        "env3 mod3 module_key lookup failed, expected 'module-env3-mod3-puppet-function'"
      )
    end

    step "env3 mod4 module_key" do
      # re3m4 = on(agent, puppet('lookup', '--environment env3', 'mod4::module_key', confdir: @confdir), :acceptable_exit_codes => [1])
    end

    step "env4 mod1 module_key" do
      re4m1 = on(agent, puppet("lookup", "--environment env4", "mod1::module_key", confdir: @confdir))
      result = re4m1.stdout
      assert_match(
        /module-env4-mod1-hiera/,
        result,
        "env4 mod2 environent_key lookup failed, expected 'module-env4-hiera'"
      )
    end

    step "env4 mod2 module_key" do
      re4m2 = on(agent, puppet("lookup", "--environment env4", "mod2::module_key", confdir: @confdir))
      result = re4m2.stdout
      assert_match(
        /module-env4-mod2-ruby-function/,
        result,
        "env4 mod2 environent_key lookup failed, expected 'module-env4-mod2-ruby-function'"
      )
    end

    step "env4 mod3 module_key" do
      re4m3 = on(agent, puppet("lookup", "--environment env4", "mod3::module_key", confdir: @confdir))
      result = re4m3.stdout
      assert_match(
        /module-env4-mod3-puppet-function/,
        result,
        "env4 mod3 module_key lookup failed, expected 'module-env4-mod3-puppet-function'"
      )
    end

    step "env4 mod4 module_key" do
      on(agent, puppet("lookup", "--environment env4", "mod4::module_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "global key explained" do
      rxg = on(agent, puppet("lookup", "--explain", "global_key", confdir: @confdir))
      result = rxg.stdout
      assert_match(
        /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*Found key.*global-hiera/,
        result,
        "global_key explained failed, expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*Found key.*global-hiera/"
      )
    end

    step "environment env1 environment_key explained" do
      rxe1 = on(agent, puppet("lookup", "--explain", "--environment env1", "environment_key", confdir: @confdir))
      result = rxe1.stdout
      assert_match(
        /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key/,
        result,
        "environment env1 enviroment_key lookup failed, expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key/"
      )
      assert_match(
        /common.*\s*.*env-env1 hiera/,
        result,
        "environment env1 enviroment_key lookup failed, expected /common.*\s*.*env-env1 hiera/"
      )
    end

    step "environment env2 environment_key explained" do
      rxe2 = on(agent, puppet("lookup", "--explain", "--environment env2", "environment_key", confdir: @confdir))
      result = rxe2.stdout
      assert_match(
        /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key/,
        result,
        "environment env2 enviroment_key lookup failed, expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key/"
      )
      assert_match(
        /eprecated API function.*\s*.*env-env2-ruby-function/,
        result,
        "environment env2 enviroment_key lookup failed, expected /eprecated API function.*\s*.*env-env2-ruby-function/"
      )
    end

    step "environment env3 environment_key explained" do
      rxe3 = on(agent, puppet("lookup", "--explain", "--environment env3", "environment_key", confdir: @confdir))
      result = rxe3.stdout
      assert_match(
        /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key/,
        result,
        "environment env3 enviroment_key lookup failed, expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key/"
      )
      assert_match(
        /eprecated API function.*\s*.*env-env3-puppet-function/,
        result,
        "environment env3 enviroment_key lookup failed, expected /eprecated API function.*\s*.*env-env3-puppet-function/"
      )
    end

    step "environment env4 environment_key explained" do
      rxe4 = on(agent, puppet("lookup", "--explain", "--environment env4", "environment_key", confdir: @confdir))
      result = rxe4.stdout
      assert_match(
        /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*environment_key/,
        result,
        "environment env4 environment_key lookup failed expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*environment_key.*\s.*did not find a value.*/"
      )
    end

    step "environment env1 mod4::module_key explained" do
      rxe1m4 = on(agent, puppet("lookup", "--explain", "--environment env1", "mod4::module_key", confdir: @confdir))
      result = rxe1m4.stdout
      assert_match(
        %r{Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*\s*Env.*\s*.*env1/hiera.yaml\"\s*Hier.*common\"\s*Path.*\s*Orig.*\s*No such key.*\s*Module data provider.*not found\s*.*did not find a value.*},
        result,
        "environment env1 mod4::module_key lookup explained failed."
      )
    end

    step "environment env2 mod3::module_key explained" do
      rxe2m3 = on(agent, puppet("lookup", "--explain", "--environment env2", "mod3::module_key", confdir: @confdir))
      result = rxe2m3.stdout
      assert_match(
        /Global Data Provider.*Using configuration.*Hierarchy entry.*Path.*No such key/m,
        result,
        "global env2 mod3::module_key lookup --explain had correct output"
      )
      assert_match(
        /Environment Data Provider.*Deprecated.*No such key/m,
        result,
        "environment env2 mod3::module_key lookup --explain had correct output"
      )
      assert_match(
        /Module.*Data Provider.*Deprecated API function "mod3::data".*Found key.*module-env2-mod3-puppet-function provided value/m,
        result,
        "module env2 mod3::module_key lookup --explain had correct output"
      )
    end

    step "environment env3 mod2::module_key explained" do
      rxe3m2 = on(agent, puppet("lookup", "--explain", "--environment env3", "mod2::module_key", confdir: @confdir))
      result = rxe3m2.stdout
      assert_match(
        /Global Data Provider.*Using configuration.*Hierarchy entry.*Path.*No such key/m,
        result,
        "global env2 mod3::module_key lookup --explain had correct output"
      )
      assert_match(
        /Environment Data Provider.*Deprecated.*No such key/m,
        result,
        "environment env2 mod3::module_key lookup --explain had correct output"
      )
      assert_match(
        /Module.*Data Provider.*Deprecated API function "mod2::data".*Found key.*module-env3-mod2-ruby-function provided value/m,
        result,
        "module env2 mod3::module_key lookup --explain had correct output"
      )
    end

    step "environment env4 mod1::module_key explained" do
      rxe4m1 = on(agent, puppet("lookup", "--explain", "--environment env4", "mod1::module_key", confdir: @confdir))
      result = rxe4m1.stdout
      assert_match(
        /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*\s*Module.*Data Provider.*\s*Using.*\s*Hier.*common\"\s*Path.*\s*Orig.*\s*Found key.*module-env4-mod1-hiera/,
        result,
        "environment env4 mod1::module_key lookup failed."
      )
    end

    step "apply env1 puppet.conf manifest" do
      apply_manifest_on(agent, @env1puppetconfmanifest, catch_failures: true)
    end

    step "puppet.conf specified environment env1 environment_key" do
      r = on(agent, puppet("lookup", "environment_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /env-env1 hiera/,
        result,
        "puppet.conf specified environment env1, environment_key lookup failed, expected /env-env1 hiera/"
      )
    end

    step "puppet.conf specified environment env1 mod4::module_key" do
      on(agent, puppet("lookup", "mod4::module_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "apply env2 puppet.conf manifest" do
      apply_manifest_on(agent, @env2puppetconfmanifest, catch_failures: true)
    end

    step "puppet.conf specified environment env2 environment_key" do
      r = on(agent, puppet("lookup", "environment_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /env-env2-ruby-function/,
        result,
        "puppet.conf specified environment env2, environment_key lookup failed, expected /env-env2-ruby-function/"
      )
    end

    step "puppet.conf specified environment env2 mod3::module_key" do
      r = on(agent, puppet("lookup", "mod3::module_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /module-env2-mod3-puppet-function/,
        result,
        "puppet.conf specified environment env2 mod3::module_key lookup failed, expeccted /module-env2-mod3-puppet-function/"
      )
    end

    step "apply env3 puppet.conf manifest" do
      apply_manifest_on(agent, @env3puppetconfmanifest, catch_failures: true)
    end

    step "puppet.conf specified environment env3 environment_key" do
      r = on(agent, puppet("lookup", "environment_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /env-env3-puppet-function/,
        result,
        "puppet.conf specified environment env1, environment_key lookup failed, expected /env-env3-puppet-function/"
      )
    end

    step "puppet.conf specified environment env3 mod2::module_key" do
      r = on(agent, puppet("lookup", "mod2::module_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /module-env3-mod2-ruby-function/,
        result,
        "puppet.conf specified environment env2 mod3::module_key lookup failed, expeccted /module-env3-mod2-ruby-function/"
      )
    end

    step "apply env4 puppet.conf manifest" do
      apply_manifest_on(agent, @env4puppetconfmanifest, catch_failures: true)
    end

    step "puppet.conf specified environment env4 environment_key" do
      on(agent, puppet("lookup", "environment_key", confdir: @confdir), acceptable_exit_codes: [1])
    end

    step "puppet.conf specified environment env4 mod1::module_key" do
      r = on(agent, puppet("lookup", "mod1::module_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /module-env4-mod1-hiera/,
        result,
        "puppet.conf specified environment env4 mod1::module_key lookup failed, expeccted /module-env4-mod1-hiera/"
      )
    end

    step "apply enc manifest" do
      apply_manifest_on(agent, @encmanifest, catch_failures: true)
    end

    step "--compile uses environment specified in ENC" do
      r = on(agent, puppet("lookup", "--compile", "--node #{@node1}", "environment_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /env-env2-ruby-function/,
        result,
        "lookup in ENC specified environment failed"
      )
    end

    step "without --compile does not use environment specified in ENC" do
      r = on(agent, puppet("lookup", "--node #{@node1}", "environment_key", confdir: @confdir))
      result = r.stdout
      assert_match(
        /env-production hiera provided value/,
        result,
        "lookup in production environment failed"
      )
    end
  end
end
