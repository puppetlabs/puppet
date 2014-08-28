test_name "puppet module generate should succeed when metadata erb template contains deprecated field 'description'"
require 'puppet/acceptance/windows_utils'
extend Puppet::Acceptance::WindowsUtils

confine :except, :platform => 'windows'

module_author = "foo"
module_name   = "bar"

agents.each do |agent|

  home_dir = nil

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
    pp = 'file { "home_dir/.puppet/var/puppet-module/skeleton/metadata.json.erb":
         ensure   => present,
         content  => "
           {
             \"name\": \"<%= metadata.full_module_name %>\",
             \"version\": \"0.1.0\",
             \"description\": \"<%= defined?(metadata.description) ? metadata.description : metadata.summary %>\",
           }"
         }'

     pp = pp.sub('home_dir', home_dir)
     apply_manifest_on(agent, pp, :catch_failures => true)
  end

  step "Generate #{module_author}-#{module_name} module as #{module_author}" do
    on agent, "su #{module_author} - -c 'cd ~ ; puppet module generate #{module_author}-#{module_name} --skip-interview'"
    on agent, "su #{module_author} - -c 'cd ~ ; cat #{home_dir}/#{module_author}-#{module_name}/metadata.json'" do |res|
      assert_match(/description/, res.stdout, "Template not correctly used")
    end
  end

end
