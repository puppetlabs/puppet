test_name 'Puppet executes functions written in the Puppet language'

tag 'audit:high',
    'audit:integration',
    'audit:refactor',     # use mk_tmp_environment_with_teardown helper for environment construction
    'server'

teardown do
  on master, 'rm -rf /etc/puppetlabs/code/modules/jenny'
  on master, 'rm -rf /etc/puppetlabs/code/environments/tommy'
  on master, 'rm -rf /etc/puppetlabs/code/environments/production/modules/one'
  on master, 'rm -rf /etc/puppetlabs/code/environments/production/modules/three'
end

step 'Create some functions' do

  manifest = <<-EOF
    File {
      ensure => 'present',
      owner => 'root',
      group => 'root',
      mode => '0644',
    }

    file {['/etc/puppetlabs/',
      '/etc/puppetlabs/code/',
      '/etc/puppetlabs/code/modules/',
      '/etc/puppetlabs/code/modules/jenny',
      '/etc/puppetlabs/code/modules/jenny/functions',
      '/etc/puppetlabs/code/modules/jenny/functions/nested',
      '/etc/puppetlabs/code/environments',
      '/etc/puppetlabs/code/environments/production',
      '/etc/puppetlabs/code/environments/production/modules',
      '/etc/puppetlabs/code/environments/production/modules/one',
      '/etc/puppetlabs/code/environments/production/modules/one/functions',
      '/etc/puppetlabs/code/environments/production/modules/one/manifests',
      '/etc/puppetlabs/code/environments/production/modules/three',
      '/etc/puppetlabs/code/environments/production/modules/three/functions',
      '/etc/puppetlabs/code/environments/production/modules/three/manifests',
      '/etc/puppetlabs/code/environments/tommy',
      '/etc/puppetlabs/code/environments/tommy/modules',
      '/etc/puppetlabs/code/environments/tommy/modules/two',
      '/etc/puppetlabs/code/environments/tommy/modules/two/functions',
      ]:
      ensure => directory,
      mode => '0755',
    }

    # "Global" functions, no env
    file { '/etc/puppetlabs/code/modules/jenny/functions/mini.pp':
      content => 'function jenny::mini($a, $b) {if $a <= $b {$a} else {$b}}',
      require => File['/etc/puppetlabs/code/modules/jenny/functions'],
    }
    file { '/etc/puppetlabs/code/modules/jenny/functions/nested/maxi.pp':
      content => 'function jenny::nested::maxi($a, $b) {if $a >= $b {$a} else {$b}}',
      require => File['/etc/puppetlabs/code/modules/jenny/functions/nested'],
    }

    # Module "one", "production" env
    file { '/etc/puppetlabs/code/environments/production/modules/one/functions/foo.pp':
      content => 'function one::foo() {"This is the one::foo() function in the production environment"}',
      require => File['/etc/puppetlabs/code/environments/production/modules/one/functions'],
    }
    file { '/etc/puppetlabs/code/environments/production/modules/one/manifests/init.pp':
      content => 'class one { }',
      require => File['/etc/puppetlabs/code/environments/production/modules/one/manifests'],
    }

    # Module "three", "production" env
    file { '/etc/puppetlabs/code/environments/production/modules/three/functions/baz.pp':
      content => 'function three::baz() {"This is the three::baz() function in the production environment"}',
      require => File['/etc/puppetlabs/code/environments/production/modules/three/functions'],
    }
    file { '/etc/puppetlabs/code/environments/production/modules/three/manifests/init.pp':
      content => 'class three { }',
      require => File['/etc/puppetlabs/code/environments/production/modules/three/functions'],
    }

    # Module "two", "tommy" env
    file { '/etc/puppetlabs/code/environments/tommy/modules/two/functions/bar.pp':
      content => 'function two::bar() {"This is the two::bar() function in the tommy environment"}',
      require => File['/etc/puppetlabs/code/environments/tommy/modules/two/functions'],
    }
    EOF
  apply_manifest_on(master, manifest, {:catch_failures => true, :acceptable_exit_codes => [0,1]})
end

manifest = <<-MANIFEST
  notice 'jenny::mini(1, 2) =', jenny::mini(1,2)
  notice 'jenny::nested::maxi(1, 2) =', jenny::nested::maxi(1,2)
  notice 'one::foo() =', one::foo()
  require 'one'; notice 'three::baz() =', three::baz()
MANIFEST

rc = apply_manifest_on(master, manifest, {:accept_all_exit_codes => true,})

step 'Call a global function' do
  fail_test 'Failed to call a "global" function' \
    unless  rc.stdout.include?('jenny::mini(1, 2) = 1')
  end

step 'Call a global nested function' do
  fail_test 'Failed to call a "global" nested function' \
    unless rc.stdout.include?('jenny::nested::maxi(1, 2) = 2')
  end

step 'Call an env-specific function' do
  fail_test 'Failed to call a function defined in the current environment' \
    unless rc.stdout.include?('This is the one::foo() function in the production environment')
  end

step 'Call a function defined in an un-included module' do
  fail_test 'Failed to call a function defined in an un-required module' \
    unless rc.stdout.include?('This is the three::baz() function in the production environment')
end

manifest = <<-MANIFEST.strip
  notice "two::bar() =", two::bar()
MANIFEST

# This should fail
step 'Call a function not defined in the current environment' do
  rc = on master, puppet("apply -e '#{manifest}' --environment production"), {:accept_all_exit_codes => true,}
  fail_test 'Should not be able to call a function not defined in the current environment' \
    unless rc.stderr.include?("Error: Evaluation Error: Unknown function: 'two::bar'")
end

step 'Call an env-specific function in a non-default environment' do
  rc = on master, puppet("apply -e '#{manifest}' --environment tommy")
  fail_test 'Failed to call env-specific function from that environment' \
    unless rc.stdout.include?('This is the two::bar() function in the tommy environment')
end

