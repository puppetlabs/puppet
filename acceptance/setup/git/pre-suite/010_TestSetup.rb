begin
  require 'beaker/dsl/install_utils'
end

test_name "Install packages and repositories on target machines..." do
  extend Beaker::DSL::InstallUtils

  SourcePath  = Beaker::DSL::InstallUtils::SourcePath
  GitURI      = Beaker::DSL::InstallUtils::GitURI
  GitHubSig   = Beaker::DSL::InstallUtils::GitHubSig

  tmp_repositories = []
  options[:install].each do |uri|
    raise(ArgumentError, "Missing GitURI argument. URI is nil.") if uri.nil?
    raise(ArgumentError, "#{uri} is not recognized.") unless(uri =~ GitURI)
    tmp_repositories << extract_repo_info_from(uri)
  end

  repositories = order_packages(tmp_repositories)

  versions = {}
  hosts.each_with_index do |host, index|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"

    repositories.each do |repository|
      step "Install #{repository[:name]}"
      if repository[:path] =~ /^file:\/\/(.+)$/
        on host, "test -d #{SourcePath} || mkdir -p #{SourcePath}"
        source_dir = $1
        checkout_dir = "#{SourcePath}/#{repository[:name]}"
        on host, "rm -f #{checkout_dir}" # just the symlink, do not rm -rf !
        on host, "ln -s #{source_dir} #{checkout_dir}"
        on host, "cd #{checkout_dir} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi"
      else
        install_from_git host, SourcePath, repository
      end

      if index == 1
        versions[repository[:name]] = find_git_repo_versions(host,
                                                             SourcePath,
                                                             repository)
      end
    end
  end

  step "Hosts: create basic puppet.conf" do
    hosts.each do |host|
      confdir = host.puppet['confdir']
      on host, "mkdir -p #{confdir}"
      puppetconf = File.join(confdir, 'puppet.conf')

      if host['roles'].include?('agent')
        on host, "echo '[agent]' > '#{puppetconf}' && " +
                 "echo server=#{master} >> '#{puppetconf}'"
      else
        on host, "touch '#{puppetconf}'"
      end
    end
  end
end
