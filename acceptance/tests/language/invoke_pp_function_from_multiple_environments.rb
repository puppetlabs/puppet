test_name 'Puppet-language functions can be called from any environment' do

  mini_func = 'function jenny::mini($a, $b) {if $a <= $b {$a} else {$b}}'
  maxi_func = 'function jenny::nested::maxi($a, $b) {if $a >= $b {$a} else {$b}}'
  step 'Create PP functions on master' do
    manifest = <<-EOM.gsub(/^ {6}/,'')
      File {
        owner => 'puppet',
        group => 'puppet',
        ensure => present,
        mode => '0644',
      }
      file {['/etc/puppetlabs',
          '/etc/puppetlabs/code',
          '/etc/puppetlabs/code/modules',
          '/etc/puppetlabs/code/modules/jenny',
          '/etc/puppetlabs/code/modules/jenny/functions',
          '/etc/puppetlabs/code/modules/jenny/functions/nested',
          '/etc/puppetlabs/code/environments',
          '/etc/puppetlabs/code/environments/frick',
          '/etc/puppetlabs/code/environments/frack',]:
        ensure => directory,
        mode => '0755',
      }
      file {'/etc/puppetlabs/code/modules/jenny/functions/mini.pp':
        content => '#{mini_func}',
      }
      file {'/etc/puppetlabs/code/modules/jenny/functions/nested/maxi.pp':
        content => '#{maxi_func}',
      }
    EOM
    apply_manifest_on(master, manifest)
  end

  applyme = <<-EOM
    class f {
      notify { 'mini': message => jenny::mini(1,2), }
      notify { 'maxi': message => jenny::nested::maxi(1,2), }
    }
    include 'f'
  EOM

  step 'Call a PP function from two environments' do
    env_1 = on master, puppet("apply -e \"#{applyme}\" --environment frick")
    fail_test "Calling PP function failed in environment 'frick'; returned #{env_1.stdout}" \
      unless env_1.stdout.include? "frick"
    fail_test "Simple PP function failed; returned #{env_1.stdout}" \
      unless env_1.stdout.include? "defined 'message' as '1'"
    fail_test "Nested PP function failed; returned #{env_1.stdout}" \
      unless env_1.stdout.include? "defined 'message' as '2'"

    env_2 = on master, puppet("apply -e '#{applyme}' --environment frack")
    fail_test "Calling PP function failed in environment 'frack'; returned #{env_2.stdout}" \
      unless env_1.stdout.include? "frick"
    fail_test "Simple PP function failed; returned #{env_2.stdout}" \
      unless env_1.stdout.include? "defined 'message' as '1'"
    fail_test "Neted PP function failed; returned #{env_2.stdout}" \
      unless env_1.stdout.include? "defined 'message' as '2'"        
  end
  
end
