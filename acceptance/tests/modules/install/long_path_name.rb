test_name "puppet module install (long file path)" do
  require 'puppet/acceptance/module_utils'
  extend Puppet::Acceptance::ModuleUtils

  confine :except, :platform => /centos-4|el-4/ # PUP-5226
  confine :except, :platform => /aix/ # PUP-5501

  module_author = 'puppetlabs'
  module_name   = 'dsc'
  module_version = '1.0.0'

  orig_installed_modules = get_installed_modules_for_hosts hosts
  teardown do
    rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
  end

  agents.each do |agent|
    step 'setup'
    stub_forge_on(agent)

    step "install module '#{module_author}-#{module_name}'"
    on(agent, puppet("module install #{module_author}-#{module_name} --version #{module_version}")) do |result|
      @module_path = /(Notice: Preparing to install into )(.*)( \.\.\.)/.match(result.stdout)[2]
      assert_module_installed_ui(stdout, module_author, module_name)
    end

    path = "#{@module_path}/#{module_name}"
    path = on(agent, "cygpath -u #{path}").stdout.chomp if /win/ =~ agent.platform

    step 'Count the files extracted from the tar'
    on(agent, "find #{path} -not -path '*/\\.*' -type f | wc -l") do |result|
      assert_match(/2602/, result.stdout, 'The correct number of files was not observed')
    end
  end
end
