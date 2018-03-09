test_name "Puppet Lookup Command"

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

# doc:
# https://docs.puppetlabs.com/puppet/latest/reference/lookup_quick_module.html

@module_name = "puppet_lookup_command_test"

### @testroot = "/etc/puppetlabs"
@testroot = master.tmpdir("#{@module_name}")

@coderoot = "#{@testroot}/code"
@confdir = "#{@testroot}/puppet"

@node1 = 'node1.example.org'
@node2 = 'node2.example.org'

@master_opts = {
  'main' => {
    'environmentpath' => "#{@coderoot}/environments",
    'hiera_config' => "#{@coderoot}/hiera.yaml",
  },
}

@manifest = <<MANIFEST
File {
  ensure => directory,
  mode => "0755",
}

file {
  '#{@confdir}':;
  '#{@coderoot}':;
  '#{@coderoot}/hieradata':;
  '#{@coderoot}/environments':;

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

  @env1puppetconfmanifest = <<MANI1
file { '#{@confdir}/puppet.conf' :
  ensure => file,
  mode => "0664",
  content => "[master]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = #{@coderoot}

[main]
environmentpath = #{@coderoot}/environments
hiera_config = #{@coderoot}/hiera.yaml
environment = env1
",
}
MANI1

  @env2puppetconfmanifest = <<MANI2
file { '#{@confdir}/puppet.conf' :
  ensure => file,
  mode => "0664",
  content => "[master]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = #{@coderoot}

[main]
environmentpath = #{@coderoot}/environments
hiera_config = #{@coderoot}/hiera.yaml
environment = env2
",
}
MANI2

  @env3puppetconfmanifest = <<MANI3
file { '#{@confdir}/puppet.conf' :
  ensure => file,
  mode => "0664",
  content => "[master]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = #{@coderoot}

[main]
environmentpath = #{@coderoot}/environments
hiera_config = #{@coderoot}/hiera.yaml
environment = env3
",
}
MANI3

  @env4puppetconfmanifest = <<MANI4
file { '#{@confdir}/puppet.conf' :
  ensure => file,
  mode => "0664",
  content => "[master]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = #{@coderoot}

[main]
environmentpath = #{@coderoot}/environments
hiera_config = #{@coderoot}/hiera.yaml
environment = env4
",
}
MANI4

  @encmanifest = <<MANIENC
## enc
file { '#{@coderoot}/enc.rb' :
  ensure => file,
  mode => "0755",
  content => "#!#{master['privatebindir']}/ruby
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
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = #{@coderoot}

[master]
node_terminus = exec
external_nodes = #{@coderoot}/enc.rb

[main]
environmentpath = #{@coderoot}/environments
hiera_config = #{@coderoot}/hiera.yaml
",
}
MANIENC

step 'apply main manifest'
apply_manifest_on(master, @manifest, :catch_failures => true)

step 'start puppet server'
with_puppet_running_on master, @master_opts, @coderoot do

  step "global_key"
  rg = on(master, puppet('lookup', 'global_key'))
  result = rg.stdout
  assert_match(
    /global-hiera/,
    result,
    "global_key lookup failed, expected 'global-hiera'"
  )

  step "production environment_key not provided"
  rep = on(master, puppet('lookup', 'enviroment_key'), :acceptable_exit_codes => [1])

  step "environment_key from environment env1"
  re1 = on(master, puppet('lookup', '--environment env1', 'environment_key'))
  result = re1.stdout
  assert_match(
    /env-env1 hiera/,
    result,
    "env1 environment_key lookup failed, expected 'env-env1 hiera'"
  )

  step "environment_key from environment env2"
  re2 = on(master, puppet('lookup', '--environment env2', 'environment_key'))
  result = re2.stdout
  assert_match(
    /env-env2-ruby-function/,
    result,
    "env2 environment_key lookup failed, expected 'env-env2-puppet-function'"
  )

  step "environment_key from environment env3"
  re3 = on(master, puppet('lookup', '--environment env3', 'environment_key'))
  result = re3.stdout
  assert_match(
    /env-env3-puppet-function/,
    result,
    "env3 environment_key lookup failed, expected 'env-env2-ruby-function data() provided value'"
  )

  step "environment_key from environment env4"
  re4 = on(master, puppet('lookup', '--environment env4', 'environment_key'), :acceptable_exit_codes => [1])

  step "production mod1 module_key"
  repm1 = on(master, puppet('lookup', 'mod1::module_key'))
  result = repm1.stdout
  assert_match(
    /module-production-mod1-hiera/,
    result,
    "production mod1 module_key lookup failed, expected 'module-production-mod1-hiera'"
  )

  step "production mod2 module_key"
  repm2 = on(master, puppet('lookup', 'mod2::module_key'))
  result = repm2.stdout
  assert_match(
    /module-production-mod2-ruby-function/,
    result,
    "production mod2 module_key lookup failed, expected 'module-production-mod2-ruby-function'"
  )

  step "production mod3 module_key"
  repm3 = on(master, puppet('lookup', 'mod3::module_key'))
  result = repm3.stdout
  assert_match(
    /module-production-mod3-puppet-function/,
    result,
    "production mod3 module_key lookup failed, expected 'module-production-mod3-puppet-function'"
  )

  step "production mod4 module_key"
  repm4 = on(master, puppet('lookup', 'mod4::module_key'), :acceptable_exit_codes => [1])

  step "env1 mod1 module_key"
  re1m1 = on(master, puppet('lookup', '--environment env1', 'mod1::module_key'))
  result = re1m1.stdout
  assert_match(
    /module-env1-mod1-hiera/,
    result,
    "env1 mod1 module_key lookup failed, expected 'module-env1-mod1-hiera'"
  )

  step "env1 mod2 module_key"
  re1m2 = on(master, puppet('lookup', '--environment env1', 'mod2::module_key'))
  result = re1m2.stdout
  assert_match(
    /module-env1-mod2-ruby-function/,
    result,
    "env1 mod2 module_key lookup failed, expected 'module-env1-mod2-ruby-function'"
  )

  step "env1 mod3 module_key"
  re1m3 = on(master, puppet('lookup', '--environment env1', 'mod3::module_key'))
  result = re1m3.stdout
  assert_match(
    /module-env1-mod3-puppet-function/,
    result,
    "env1 mod3 module_key lookup failed, expected 'module-env1-mod3-puppet-function'"
  )

  step "env1 mod4 module_key"
  re1m4 = on(master, puppet('lookup', '--environment env1', 'mod4::module_key'), :acceptable_exit_codes => [1])

  step "env2 mod1 module_key"
  re2m1 = on(master, puppet('lookup', '--environment env2', 'mod1::module_key'))
  result = re2m1.stdout
  assert_match(
    /module-env2-mod1-hiera/,
    result,
    "env2 mod1 module_key lookup failed, expected 'module-env2-mod1-hiera'"
  )

  step "env2 mod2 module_key"
  re2m2 = on(master, puppet('lookup', '--environment env2', 'mod2::module_key'))
  result = re2m2.stdout
  assert_match(
    /module-env2-mod2-ruby-function/,
    result,
    "env2 mod2 module_key lookup failed, expected 'module-env2-mod2-ruby-function'"
  )

  step "env2 mod3 module_key"
  re2m3 = on(master, puppet('lookup', '--environment env2', 'mod3::module_key'))
  result = re2m3.stdout
  assert_match(
    /module-env2-mod3-puppet-function/,
    result,
    "env2 mod3 module_key lookup failed, expected 'module-env2-mod3-puppet-function'"
  )

  step "env2 mod4 module_key"
  re2m4 = on(master, puppet('lookup', '--environment env2', 'mod4::module_key'), :acceptable_exit_codes => [1])

  step "env3 mod1 module_key"
  re3m1 = on(master, puppet('lookup', '--environment env3', 'mod1::module_key'))
  result = re3m1.stdout
  assert_match(
    /module-env3-mod1-hiera/,
    result,
    "env3 mod1 module_key lookup failed, expected 'module-env3-mod1-hiera'"
  )

  step "env3 mod2 module_key"
  re3m2 = on(master, puppet('lookup', '--environment env3', 'mod2::module_key'))
  result = re3m2.stdout
  assert_match(
    /module-env3-mod2-ruby-function/,
    result,
    "env3 mod2 module_key lookup failed, expected 'module-env3-mod2-ruby-function'"
  )

  step "env3 mod3 module_key"
  re3m3 = on(master, puppet('lookup', '--environment env3', 'mod3::module_key'))
  result = re3m3.stdout
  assert_match(
    /module-env3-mod3-puppet-function/,
    result,
    "env3 mod3 module_key lookup failed, expected 'module-env3-mod3-puppet-function'"
  )

  step "env3 mod4 module_key"
#   re3m4 = on(master, puppet('lookup', '--environment env3', 'mod4::module_key'), :acceptable_exit_codes => [1])

  step "env4 mod1 module_key"
  re4m1 = on(master, puppet('lookup', '--environment env4', 'mod1::module_key'))
  result = re4m1.stdout
  assert_match(
    /module-env4-mod1-hiera/,
    result,
    "env4 mod2 environent_key lookup failed, expected 'module-env4-hiera'"
  )


  step "env4 mod2 module_key"
  re4m2 = on(master, puppet('lookup', '--environment env4', 'mod2::module_key'))
  result = re4m2.stdout
  assert_match(
    /module-env4-mod2-ruby-function/,
    result,
    "env4 mod2 environent_key lookup failed, expected 'module-env4-mod2-ruby-function'"
  )

  step "env4 mod3 module_key"
  re4m3 = on(master, puppet('lookup', '--environment env4', 'mod3::module_key'))
  result = re4m3.stdout
  assert_match(
    /module-env4-mod3-puppet-function/,
    result,
    "env4 mod3 module_key lookup failed, expected 'module-env4-mod3-puppet-function'"
  )

  step "env4 mod4 module_key"
  re4m4 = on(master, puppet('lookup', '--environment env4', 'mod4::module_key'), :acceptable_exit_codes => [1])

  step "global key explained"
  rxg = on(master, puppet('lookup', '--explain', 'global_key'))
  result = rxg.stdout
  assert_match(
    /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*Found key.*global-hiera/,
    result,
    "global_key explained failed, expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*Found key.*global-hiera/"
  )

  step "environment env1 environment_key explained"
  rxe1 = on(master, puppet('lookup', '--explain', '--environment env1', 'environment_key'))
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

  step "environment env2 environment_key explained"
  rxe2 = on(master, puppet('lookup', '--explain', '--environment env2', 'environment_key'))
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

  step "environment env3 environment_key explained"
  rxe3 = on(master, puppet('lookup', '--explain', '--environment env3', 'environment_key'))
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

  step "environment env4 environment_key explained"
  rxe4 = on(master, puppet('lookup', '--explain', '--environment env4', 'environment_key'))
  result = rxe4.stdout
  assert_match(
    /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*environment_key/,
    result,
    "environment env4 environment_key lookup failed expected /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*environment_key.*\s.*did not find a value.*/"
  )

  step "environment env1 mod4::module_key explained"
  rxe1m4 = on(master, puppet('lookup', '--explain', '--environment env1', 'mod4::module_key'))
  result = rxe1m4.stdout
  assert_match(
    /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*\s*Env.*\s*.*env1\/hiera.yaml\"\s*Hier.*common\"\s*Path.*\s*Orig.*\s*No such key.*\s*Module data provider.*not found\s*.*did not find a value.*/,
    result,
    "environment env1 mod4::module_key lookup explained failed."
  )

  step "environment env2 mod3::module_key explained"
  rxe2m3 = on(master, puppet('lookup', '--explain', '--environment env2', 'mod3::module_key'))
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

  step "environment env3 mod2::module_key explained"
  rxe3m2 = on(master, puppet('lookup', '--explain', '--environment env3', 'mod2::module_key'))
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

  step "environment env4 mod1::module_key explained"
  rxe4m1 = on(master, puppet('lookup', '--explain', '--environment env4', 'mod1::module_key'))
  result = rxe4m1.stdout
  assert_match(
    /Global Data Provider.*\s*Using.*\s*Hier.*\s*Path.*\s*Orig.*\s*No such key.*\s*Module.*Data Provider.*\s*Using.*\s*Hier.*common\"\s*Path.*\s*Orig.*\s*Found key.*module-env4-mod1-hiera/,
    result,
    "environment env4 mod1::module_key lookup failed."
  )

  step 'apply env1 puppet.conf manifest'
  apply_manifest_on(master, @env1puppetconfmanifest, :catch_failures => true)

  step "puppet.conf specified environment env1 environment_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'environment_key'))
  result = r.stdout
  assert_match(
    /env-env1 hiera/,
    result,
    "puppet.conf specified environment env1, environment_key lookup failed, expected /env-env1 hiera/"
  )

  step "puppet.conf specified environment env1 mod4::module_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'mod4::module_key'), :acceptable_exit_codes => [1])

  step 'apply env2 puppet.conf manifest'
  apply_manifest_on(master, @env2puppetconfmanifest, :catch_failures => true)

  step "puppet.conf specified environment env2 environment_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'environment_key'))
  result = r.stdout
  assert_match(
    /env-env2-ruby-function/,
    result,
    "puppet.conf specified environment env2, environment_key lookup failed, expected /env-env2-ruby-function/"
  )

  step "puppet.conf specified environment env2 mod3::module_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'mod3::module_key'))
  result = r.stdout
  assert_match(
    /module-env2-mod3-puppet-function/,
    result,
    "puppet.conf specified environment env2 mod3::module_key lookup failed, expeccted /module-env2-mod3-puppet-function/"
  )

  step 'apply env3 puppet.conf manifest'
  apply_manifest_on(master, @env3puppetconfmanifest, :catch_failures => true)

  step "puppet.conf specified environment env3 environment_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'environment_key'))
  result = r.stdout
  assert_match(
    /env-env3-puppet-function/,
    result,
    "puppet.conf specified environment env1, environment_key lookup failed, expected /env-env3-puppet-function/"
  )

  step "puppet.conf specified environment env3 mod2::module_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'mod2::module_key'))
  result = r.stdout
  assert_match(
    /module-env3-mod2-ruby-function/,
    result,
    "puppet.conf specified environment env2 mod3::module_key lookup failed, expeccted /module-env3-mod2-ruby-function/"
  )

  step 'apply env4 puppet.conf manifest'
  apply_manifest_on(master, @env4puppetconfmanifest, :catch_failures => true)

  step "puppet.conf specified environment env4 environment_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'environment_key'), :acceptable_exit_codes => [1])

  step "puppet.conf specified environment env4 mod1::module_key"
  r = on(master, puppet('lookup', "--confdir #{@confdir}", 'mod1::module_key'))
  result = r.stdout
  assert_match(
    /module-env4-mod1-hiera/,
    result,
    "puppet.conf specified environment env4 mod1::module_key lookup failed, expeccted /module-env4-mod1-hiera/"
  )

  step 'apply enc manifest'
  apply_manifest_on(master, @encmanifest, :catch_failures => true)

  step "--compile uses environment specified in ENC"
  r = on(master, puppet('lookup', '--compile', "--node #{@node1}", "--confdir #{@confdir}", 'environment_key'))
  result = r.stdout
  assert_match(
    /env-env2-ruby-function/,
    result,
    "lookup in ENC specified environment failed"
  )

  step "without --compile does not use environment specified in ENC"
  r = on(master, puppet('lookup', "--node #{@node1}", "--confdir #{@confdir}", 'environment_key'))
  result = r.stdout
  assert_match(
    /env-production hiera provided value/,
    result,
    "lookup in production environment failed"
  )

end
