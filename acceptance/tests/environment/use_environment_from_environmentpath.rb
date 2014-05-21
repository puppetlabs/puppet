test_name "Use environments from the environmentpath"

testdir = master.tmpdir('use_environmentpath')

def generate_environment(path_to_env, environment)
  env_content = <<-EOS
  "#{path_to_env}/#{environment}":;
  "#{path_to_env}/#{environment}/manifests":;
  "#{path_to_env}/#{environment}/modules":;
  EOS
end

def generate_module_content(module_name, options = {})
  base_path = options[:base_path]
  environment = options[:environment]
  env_path = options[:env_path]

  path_to_module = [base_path, env_path, environment, "modules"].compact.join("/")
  module_info = "module-#{module_name}"
  module_info << "-from-#{environment}" if environment

  module_content = <<-EOS
  "#{path_to_module}/#{module_name}":;
  "#{path_to_module}/#{module_name}/manifests":;
  "#{path_to_module}/#{module_name}/files":;
  "#{path_to_module}/#{module_name}/templates":;
  "#{path_to_module}/#{module_name}/lib":;
  "#{path_to_module}/#{module_name}/lib/facter":;

  "#{path_to_module}/#{module_name}/manifests/init.pp":
    ensure => file,
    mode => 0640,
    content => 'class #{module_name} {
      notify { "template-#{module_name}": message => template("#{module_name}/our_template.erb") }
      file { "$agent_file_location/file-#{module_info}": source => "puppet:///modules/#{module_name}/data" }
    }'
  ;
  "#{path_to_module}/#{module_name}/lib/facter/environment_fact_#{module_name}.rb":
    ensure => file,
    mode => 0640,
    content => "Facter.add(:environment_fact_#{module_name}) { setcode { 'environment fact from #{module_info}' } }"
  ;
  "#{path_to_module}/#{module_name}/files/data":
    ensure => file,
    mode => 0640,
    content => "data file from #{module_info}"
  ;
  "#{path_to_module}/#{module_name}/templates/our_template.erb":
    ensure => file,
    mode => 0640,
    content => "<%= @environment_fact_#{module_name} %>"
  ;
  EOS
end

def generate_site_manifest(path_to_manifest, *modules_to_include)
  manifest_content = <<-EOS
  "#{path_to_manifest}/site.pp":
    ensure => file,
    mode => 0640,
    content => "#{modules_to_include.map { |m| "include #{m}" }.join("\n")}"
  ;
  EOS
end

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => #{master['user']},
  group => #{master['group']},
  mode => 0750,
}

file {
  "#{testdir}":;
  "#{testdir}/base":;
  "#{testdir}/additional":;
  "#{testdir}/modules":;
#{generate_environment("#{testdir}/base", "shadowed")}
#{generate_environment("#{testdir}/base", "onlybase")}
#{generate_environment("#{testdir}/additional", "shadowed")}

#{generate_module_content("atmp",
    :base_path => testdir,
    :env_path => 'base',
    :environment => 'shadowed')}
#{generate_site_manifest("#{testdir}/base/shadowed/manifests", "atmp", "globalmod")}

#{generate_module_content("atmp",
    :base_path => testdir,
    :env_path => 'base',
    :environment => 'onlybase')}
#{generate_site_manifest("#{testdir}/base/onlybase/manifests", "atmp", "globalmod")}

#{generate_module_content("atmp",
    :base_path => testdir,
    :env_path => 'additional',
    :environment => 'shadowed')}
#{generate_site_manifest("#{testdir}/additional/shadowed/manifests", "atmp", "globalmod")}

# And one global module (--modulepath setting)
#{generate_module_content("globalmod", :base_path => testdir)}
}
MANIFEST

def run_with_environment(agent, environment, options = {})
  expected_exit_code = options[:expected_exit_code] || 2
  expected_strings = options[:expected_strings]

  step "running an agent in environment '#{environment}'"
  atmp = agent.tmpdir("use_environmentpath_#{environment}")

  agent_config = [
    "-t",
    "--server", master,
  ]
  agent_config << '--environment' << environment if environment
  agent_config << {
    'ENV' => { "FACTER_agent_file_location" => atmp },
  }

  on(agent,
     puppet("agent", *agent_config),
     :acceptable_exit_codes => [expected_exit_code]) do |result|

    yield atmp, result
  end

  on agent, "rm -rf #{atmp}"
end

master_opts = {
  'master' => {
    'environmentpath' => "#{testdir}/additional:#{testdir}/base",
    'basemodulepath' => "#{testdir}/modules",
  }
}
if master.is_pe?
  master_opts['master']['basemodulepath'] << ":#{master['sitemoduledir']}"
end

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    run_with_environment(agent, "shadowed") do |tmpdir,catalog_result|
      ["module-atmp-from-shadowed", "module-globalmod"].each do |expected|
        assert_match(/environment fact from #{expected}/, catalog_result.stdout)
      end

      ["module-atmp-from-shadowed", "module-globalmod"].each do |expected|
        on agent, "cat #{tmpdir}/file-#{expected}" do |file_result|
          assert_match(/data file from #{expected}/, file_result.stdout)
        end
      end
    end

    run_with_environment(agent, "onlybase") do |tmpdir,catalog_result|
      ["module-atmp-from-onlybase", "module-globalmod"].each do |expected|
        assert_match(/environment fact from #{expected}/, catalog_result.stdout)
      end

      ["module-atmp-from-onlybase", "module-globalmod"].each do |expected|
        on agent, "cat #{tmpdir}/file-#{expected}" do |file_result|
          assert_match(/data file from #{expected}/, file_result.stdout)
        end
      end
    end

    if master.is_pe?
      step("This test cannot run if the production environment directory does not exist, because the fallback production environment puppet creates has an empty modulepath and PE cannot run without it's basemodulepath in /opt.  PUP-2519, which implicitly creates the production environment directory should allow this to run again")
    else
      run_with_environment(agent, nil, :expected_exit_code => 0) do |tmpdir, result|
        assert_no_match(/module-atmp/, result.stdout, "module-atmp was included despite no environment being loaded")
        assert_match(/Loading facts.*globalmod/, result.stdout)
      end
    end
  end
end
