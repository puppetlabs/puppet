test_name 'utf-8 characters in module doc string, puppet describe' do

  tag 'audit:medium',      # utf-8 is high impact in general, puppet describe low risk?
      'audit:integration', # not package dependent but may want to vary platform by LOCALE/encoding
      'audit:refactor'     # if keeping, use mk_temp_environment_with_teardown
                           # remove with_puppet_running_on unless pluginsync is absolutely necessary
                           # (if it is, add 'server' tag

  platforms = hosts.map {|val| val[:platform]}
  if (platforms.any? { |val| /^eos-/ =~ val})
    skip_test "Skipping because Puppet describe fails when the Arista module is installed (ARISTA-51)"
  end 

  # utf8chars = "€‰ㄘ万竹ÜÖ"
  utf8chars = "\u20ac\u2030\u3118\u4e07\u7af9\u00dc\u00d6"

  master_mod_dir = master.tmpdir("describe_master")
  on(master, "chmod -R 755 #{master_mod_dir}");
  teardown do
    on(master, "rm -rf #{master_mod_dir}")
  end
  master_manifest = 
<<MASTER_MANIFEST

File {
  ensure => directory,
  mode => "0755",
}

file {
  '#{master_mod_dir}/code':;
  '#{master_mod_dir}/code/environments':;
  '#{master_mod_dir}/code/environments/production':;
  '#{master_mod_dir}/code/environments/production/modules':;
  '#{master_mod_dir}/code/environments/production/modules/master_mytype_module':;
  '#{master_mod_dir}/code/environments/production/modules/master_mytype_module/lib':;
  '#{master_mod_dir}/code/environments/production/modules/master_mytype_module/lib/puppet':;
  '#{master_mod_dir}/code/environments/production/modules/master_mytype_module/lib/puppet/type':;
}

file { '#{master_mod_dir}/code/environments/production/modules/master_mytype_module/lib/puppet/type/master_mytype.rb' :
  ensure => file,
  mode => '0755',
  content => '
Puppet::Type.newtype(:master_mytype) do
  @doc = "Testing to see if puppet handles describe blocks correctly
when they contain utf8 characters, such as #{utf8chars}
"
  newparam(:name) do
    isnamevar
    desc " name parameter for mytype, also with some utf8 chars #{utf8chars}"
  end
end
',
}

MASTER_MANIFEST

  step "Apply master manifest" do
    apply_manifest_on(master, master_manifest)
  end
  master_opts = {
    'main' => {
       'environmentpath' => "#{master_mod_dir}/code/environments",
    }
  }

  step "Start puppet server"
  with_puppet_running_on(master, master_opts, master_mod_dir) do
    agents.each do |agent|
      puts "agent name: #{agent.hostname}, platform: #{agent.platform}"
      step "Run puppet agent for plugin sync" do 
        on(
          agent, puppet("agent", "-t", "--server #{master.node_name}"),
          :acceptable_exit_codes => [0, 2]
        )
      end

      step "Puppet describe for master-hosted mytype" do 
        on(agent, puppet("describe", "master_mytype")) do |result|
          assert_match(
            /master_mytype.*such as #{utf8chars}/m,
            result.stdout,
  "Main description of master_mytype did not match utf8 chars, '#{utf8chars}'"
          )

          assert_match(
            /name parameter.*chars #{utf8chars}/,
            result.stdout,
            "Name parameter description of master_mytype did not match utf8 chars, '#{utf8chars}'"
          )
        end
      end
    end
  end
end
