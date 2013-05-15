begin
  require 'puppet_acceptance/dsl/install_utils'
rescue LoadError
  require File.expand_path(File.join(__FILE__, '..', '..', '..', 'lib', 'puppet_acceptance', 'dsl', 'install_utils'))
end

test_name "Install packages and repositories on target machines..." do
  extend PuppetAcceptance::DSL::InstallUtils

  SourcePath  = PuppetAcceptance::DSL::InstallUtils::SourcePath
  GitURI      = PuppetAcceptance::DSL::InstallUtils::GitURI
  GitHubSig   = PuppetAcceptance::DSL::InstallUtils::GitHubSig

  tmp_repositories = []
  options[:install].each do |uri|
    raise(ArgumentError, "#{uri} is not recognized.") unless(uri =~ GitURI)
    tmp_repositories << extract_repo_info_from(uri)
  end

  repositories = order_packages(tmp_repositories)

  versions = {}
  hosts.each_with_index do |host, index|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"

    repositories.each do |repository|
      step "Install #{repository[:name]}"
      install_from_git host, SourcePath, repository

      if index == 1
        versions[repository[:name]] = find_git_repo_versions(host,
                                                             SourcePath,
                                                             repository)
      end
    end
  end

  config[:version] = versions

  step "Agents: create basic puppet.conf" do
    agents.each do |agent|
      puppetconf = File.join(agent['puppetpath'], 'puppet.conf')

      on agent, "echo '[agent]' > #{puppetconf} && " +
                "echo server=#{master} >> #{puppetconf}"
    end
  end
end
