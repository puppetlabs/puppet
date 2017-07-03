test_name "Environment control of static catalogs"

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor',  # use mk_tmp_environment_with_teardown helper for environment construction
    'server'

skip_test 'requires puppetserver to test static catalogs' if @options[:type] != 'aio'

require 'json'

@testroot = master.tmpdir(File.basename(__FILE__, '/*'))
@coderoot = "#{@testroot}/code"
@confdir = master['puppetserver-confdir']
@master_opts = {
  'main' => {
    'environmentpath' => "#{@coderoot}/environments",
  },
}
@production_files = {}
@canary_files = {}
@agent_manifests = {}
@catalog_files = {}
agents.each do |agent|
  hn = agent.node_name
  resdir = agent.tmpdir('results')
  @production_files[hn] = "#{resdir}/prod_hello_from_puppet_uri"
  @canary_files[hn] = "#{resdir}/can_hello_from_puppet_uri"
  @catalog_files[hn] = "#{on(agent, puppet('config', 'print', 'client_datadir')).stdout.chomp}/catalog/#{hn}.json"
  @agent_manifests[hn] = <<MANIFESTAGENT
file { '#{@coderoot}/environments/production/modules/hello/manifests/init.pp':
  ensure => file,
  mode => "0644",
  content => "class hello {
  notice('hello from production-hello')
  file { '#{resdir}' :
    ensure => directory,
    mode => '0755',
  }
  file { '#{resdir}/prod_hello_from_puppet_uri' :
    ensure => file,
    mode => '0644',
    source => 'puppet:///modules/hello/hello_msg',
  }
}",
}

file { '#{@coderoot}/environments/canary/modules/can_hello/manifests/init.pp':
  ensure => file,
  mode => "0644",
  content => 'class can_hello {
  notice("hello from production-hello")
  file { "#{resdir}":
    ensure => directory,
    mode => "0755",
  }
  file { "#{resdir}/can_hello_from_puppet_uri" :
    ensure => file,
    mode => "0644",
    source => "puppet:///modules/can_hello/hello_msg",
  }
}',
}
MANIFESTAGENT
end

@manifest = <<MANIFEST
File {
  ensure => directory,
  mode => "0755",
}

file {
  '#{@testroot}':;
  '#{@coderoot}':;
  '#{@coderoot}/environments':;
  '#{@coderoot}/environments/production':;
  '#{@coderoot}/environments/production/manifests':;
  '#{@coderoot}/environments/production/modules':;
  '#{@coderoot}/environments/production/modules/hello':;
  '#{@coderoot}/environments/production/modules/hello/manifests':;
  '#{@coderoot}/environments/production/modules/hello/files':;

  '#{@coderoot}/environments/canary':;
  '#{@coderoot}/environments/canary/manifests':;
  '#{@coderoot}/environments/canary/modules':;
  '#{@coderoot}/environments/canary/modules/can_hello':;
  '#{@coderoot}/environments/canary/modules/can_hello/manifests':;
  '#{@coderoot}/environments/canary/modules/can_hello/files':;

}

file { '#{@coderoot}/code_id.sh' :
  ensure => file,
  mode => "0755",
  content => '#! /bin/bash
echo "code_version_1"
',
}

file { '#{@coderoot}/code_content.sh' :
  ensure => file,
  mode => "0755",
  content => '#! /bin/bash
if [ $2 == "code_version_1" ] ; then
  echo "code_version_1"
else
  echo "newer_version"
fi
',
}

file { '#{@coderoot}/environments/production/environment.conf':
  ensure => file,
  mode => "0644",
  content => 'environment_timeout = 0
',
}

file { '#{@coderoot}/environments/canary/environment.conf':
  ensure => file,
  mode => "0644",
  content => 'environment_timeout = 0
static_catalogs = false
',
}

file { '#{@coderoot}/environments/production/manifests/site.pp':
  ensure => file,
  mode => "0644",
  content => "node default {
  include hello
}
",
}

file { '#{@coderoot}/environments/canary/manifests/site.pp':
  ensure => file,
  mode => "0644",
  content => "node default {
  include can_hello
}
",
}

file { '#{@coderoot}/environments/production/modules/hello/files/hello_msg':
  ensure => file,
  mode => "0644",
  content => "Hello message from production/hello module, content from source attribute.
",
}

file { '#{@coderoot}/environments/canary/modules/can_hello/files/hello_msg':
  ensure => file,
  mode => "0644",
  content => "Hello message from canary/can_hello module, content from source attribute.
",
}
MANIFEST

teardown do
  on(master, "mv #{@confdir}/puppetserver.conf.bak #{@confdir}/puppetserver.conf")
  on(master, "rm -rf #{@testroot}")
end

step 'apply main manifest, static_catalogs unspecified in global scope, unspecified in production environment, disabled in canary environment'
on(
  master,
  "cp #{@confdir}/puppetserver.conf #{@confdir}/puppetserver.conf.bak"
)
apply_manifest_on(master, @manifest, :catch_failures => true)

step "Add versioned-code parameters to puppetserver.conf and ensure the server is running"
puppetserver_config = "#{master['puppetserver-confdir']}/puppetserver.conf"
on master, "cp #{puppetserver_config} #{@coderoot}/puppetserver.conf.bak"
versioned_code_settings = {
  "jruby-puppet" => {
    "master-code-dir" => @coderoot
  },
  "versioned-code" => {
    "code-id-command" => "#{@coderoot}/code_id.sh",
     "code-content-command" => "#{@coderoot}/code_content.sh"
  }
}
modify_tk_config(master, puppetserver_config, versioned_code_settings)

step 'start puppet server'
with_puppet_running_on master, @master_opts, @coderoot do
  agents.each do |agent|
    hn = agent.node_name

    apply_manifest_on(master, @agent_manifests[hn], :catch_failures => true)

    step 'agent gets a production catalog, should be static catalog by default'
    on(
      agent,
      puppet(
        'agent',
        '-t',
        '--environment', 'production',
        '--server', master.node_name
      ),
      :acceptable_exit_codes => [0, 2]
    )

    step 'verify production environment'
    r = on(agent, "cat #{@catalog_files[hn]}")
    catalog_content = JSON.parse(r.stdout)
    assert_equal(
      catalog_content['environment'],
      'production',
      'catalog for unexpectected environment'
    )

    step 'verify static catalog by finding metadata section in catalog'
    assert(
      catalog_content['metadata'] && catalog_content['metadata'][@production_files[hn]],
      'metadata section of catalog not found'
    )

    step 'agent gets a canary catalog, static catalog should be disabled'
    on(
      agent,
      puppet(
        'agent',
        '-t',
        '--environment', 'canary',
        '--server', master.node_name
      ),
      :acceptable_exit_codes => [0, 2]
    )

    step 'verify canary environment'
    r = on(agent, "cat #{@catalog_files[hn]}")
    catalog_content = JSON.parse(r.stdout)
    assert_equal(
      catalog_content['environment'],
      'canary',
      'catalog for unexpectected environment'
    )

    step 'verify not static catalog by absence of metadata section in catalog'
    assert_nil(
      catalog_content['metadata'],
      'unexpected metadata section found in catalog'
    )

  end
end

step 'enable static catalog for canary environment'
@static_canary_manifest = <<MANIFEST2
file { '#{@coderoot}/environments/canary/environment.conf':
  ensure => file,
  mode => "0644",
  content => 'environment_timeout = 0
static_catalogs = true
',
}
MANIFEST2
apply_manifest_on(master, @static_canary_manifest, :catch_failures => true)

step 'disable global static catalog setting'
@master_opts = {
  'master' => {
    'static_catalogs' => false
  },
  'main' => {
    'environmentpath' => "#{@coderoot}/environments",
  },
}

step 'bounce server for static catalog disable setting to take effect.'
with_puppet_running_on master, @master_opts, @coderoot do
  agents.each do |agent|
    hn = agent.node_name

    apply_manifest_on(master, @agent_manifests[hn], :catch_failures => true)

    step 'agent gets a production catalog, should not be a static catalog'
    on(
      agent,
      puppet(
        'agent',
        '-t',
        '--environment', 'production',
        '--server', master.node_name
      ),
      :acceptable_exit_codes => [0, 2]
    )

    step 'verify production environment'
    r = on(agent, "cat #{@catalog_files[hn]}")
    catalog_content = JSON.parse(r.stdout)
    assert_equal(
      catalog_content['environment'],
      'production',
      'catalog for unexpectected environment'
    )

    step 'verify production environment, not static catalog'
    assert_nil(
      catalog_content['metadata'],
      'unexpected metadata section found in catalog'
    )

    step 'agent gets a canary catalog, static catalog should be enabled'
    on(
      agent,
      puppet(
        'agent',
        '-t',
        '--environment', 'canary',
        '--server', master.node_name
      ),
      :acceptable_exit_codes => [0, 2]
    )

    step 'verify canary catalog'
    r = on(agent, "cat #{@catalog_files[hn]}")
    catalog_content = JSON.parse(r.stdout)
    assert_equal(
      catalog_content['environment'],
      'canary',
      'catalog for unexpectected environment'
    )

    step 'verify canary static catalog'
    assert(
      catalog_content['metadata'] && catalog_content['metadata'][@canary_files[hn]],
      'metadata section of catalog not found'
    )

  end
end
