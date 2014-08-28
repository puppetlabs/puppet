test_name "puppet module generate should support erb templates in skeleton"
require 'puppet/acceptance/windows_utils'
extend Puppet::Acceptance::WindowsUtils

confine :except, :platform => 'windows'

module_author = "foo"
module_name   = "bar"

agents.each do |agent|

  teardown do
    apply_manifest_on(agent, "user { '#{module_author}': ensure => absent, managehome => true, }", :catch_failures => true)
  end

  step "Create non-privileged user" do
    # The use of skeleton data is not supported for privileged user

    home_prop = nil
    case agent['platform']
    when /windows/
      home_prop = "home='#{profile_base(agent)}\\#{module_author}'"
    when /solaris/
      pending_test("managehome needs work on solaris")
    end

    on agent, puppet_resource('user', module_author, ["ensure=present", "managehome=true", "password='Puppet11'", home_prop].compact)
  end

  step "Add skeleton .fixtures.yml.erb file" do
    home_dir = nil
    on agent, puppet_resource('user', module_author) do |result|
      home_dir = result.stdout.match(/home\s*=>\s*'([^']+)'/m)[1]
    end
    pp = "file { [ '#{home_dir}/.puppet',
                   '#{home_dir}/.puppet/var',
                   '#{home_dir}/.puppet/var/puppet-module',
                   '#{home_dir}/.puppet/var/puppet-module/skeleton' ]:
         ensure   => 'directory',
         owner    => '#{module_author}',
         }"
    apply_manifest_on(agent, pp, :catch_failures => true)
    pp = 'file { "home_dir/.puppet/var/puppet-module/skeleton/.fixtures.yml.erb":
         ensure   => present,
         content  => "fixtures:
           repositories:
             stdlib: \"git://github.com/puppetlabs/puppetlabs-stdlib.git\"
           symlinks:
             <%= metadata.name %>: \"#{source_dir}\"",
         }'
     pp = pp.sub('home_dir', home_dir)
     apply_manifest_on(agent, pp, :catch_failures => true)
  end

  step "Generate #{module_author}-#{module_name} module as #{module_author}" do
    on agent, "su #{module_author} - -c 'cd ~ ; puppet module generate #{module_author}-#{module_name} --skip-interview'"
  end

  step "Check for template in #{module_author}-#{module_name}" do
    expected = 'fixtures:
           repositories:
             stdlib: "git://github.com/puppetlabs/puppetlabs-stdlib.git"
           symlinks:
             bar: "#{source_dir}"'

    on agent,"test -f /home/#{module_author}/#{module_author}-#{module_name}/.fixtures.yml"
    on agent,"cat /home/#{module_author}/#{module_author}-#{module_name}/.fixtures.yml" do |res|
      assert_equal(expected, res.stdout)
    end
  end

end
