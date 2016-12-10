test_name "Install packages and repositories on target machines..." do
require 'beaker/dsl/install_utils'
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
        create_remote_file(host, '/tmp/Gemfile', <<END)
source ENV['GEM_SOURCE'] || 'https://rubygems.org'
gem '#{repository[:name]}', :git => '#{repository[:path]}', :ref => '#{ENV['SHA']}'
END
        on host, "cd /tmp && bundle install --system --binstubs /usr/bin --standalone"
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

  step "Hosts: create environments directory like AIO does" do
    hosts.each do |host|
      on host, "mkdir -p /etc/puppetlabs/code/environments/production/manifests"
      on host, "mkdir -p /etc/puppetlabs/code/environments/production/modules"
      on host, "chmod -R 755 /etc/puppetlabs/code"
    end
  end
end
