test_name 'Puppet-language functions can be called from inside an another module' do

  mini_func = 'function jenny::mini($a, $b) {if $a <= $b {$a} else {$b}}'
  maxi_func = 'function jenny::nested::maxi($a, $b) {if $a >= $b {$a} else {$b}}'
  
  step 'Create PP functions on master' do
    manifest = <<-EOM.gsub(/^ {6}/,'')
      File {
        ensure => present,
        owner => 'puppet',
        group => 'puppet',
        mode => '0644',
      }
      file {['/etc/puppetlabs',
        '/etc/puppetlabs/code',
        '/etc/puppetlabs/code/modules/',
        '/etc/puppetlabs/code/modules/jenny',
        '/etc/puppetlabs/code/modules/jenny/functions',
        '/etc/puppetlabs/code/modules/jenny/functions/nested',
        '/etc/puppetlabs/code/modules/tommy',
        '/etc/puppetlabs/code/modules/tommy/manifests',
        '/etc/puppetlabs/code/modules/tutone',
        '/etc/puppetlabs/code/modules/tutone/manifests']:
        ensure => directory,
        mode => '0755',
      }      
      file {'/etc/puppetlabs/code/modules/jenny/functions/mini.pp':
        content => '#{mini_func}',
      }
      file {'/etc/puppetlabs/code/modules/jenny/functions/nested/maxi.pp':
        content => '#{maxi_func}',
      }
      file {'/etc/puppetlabs/code/modules/tommy/manifests/init.pp':
        content => 'class tommy { notify { "tommy says FOO": } }',
      }
      file {'/etc/puppetlabs/code/modules/tutone/manifests/testmini.pp':
        content => 'require "tommy"; notify {"mini": message => jenny::mini(1,2)}'
      }
      file {'/etc/puppetlabs/code/modules/tutone/manifests/testmaxi.pp':
        content => 'require "tommy"; notify {"maxi": message => jenny::nested::maxi(1,2)}'
      }
    EOM
    apply_manifest_on(master, manifest)
  end

  step 'Call a simple PP function from another module' do
    rc = on master, puppet('apply /etc/puppetlabs/code/modules/tutone/manifests/testmini.pp')
    fail_test "Dependent simple PP function failed; returned #{rc.stdout}" \
      unless rc.stdout.include? "defined 'message' as '1'"
  end

  step 'Call a nested PP function from another module' do
    rc = on master, puppet('apply /etc/puppetlabs/code/modules/tutone/manifests/testmaxi.pp')
    fail_test "Dependent nested PP function failed; returned #{rc.stdout}" \
      unless rc.stdout.include? "defined 'message' as '2'"
  end

end
