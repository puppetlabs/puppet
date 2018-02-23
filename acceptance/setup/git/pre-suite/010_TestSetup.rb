test_name "Install packages and repositories on target machines..." do
  require 'beaker/dsl/install_utils'
  extend Beaker::DSL::InstallUtils

  SourcePath  = Beaker::DSL::InstallUtils::SourcePath
  GitHubSig   = Beaker::DSL::InstallUtils::GitHubSig

  repositories = options[:install].map do |url|
    extract_repo_info_from(build_git_url(url))
  end

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
        puppet_dir = host.tmpdir('puppet')
        on(host, "chmod 755 #{puppet_dir}")

        sha = ENV['SHA'] || `git rev-parse HEAD`.chomp
        gem_source = ENV["GEM_SOURCE"] || "https://rubygems.org"
        gemfile_contents = <<END
source '#{gem_source}'
gem '#{repository[:name]}', :git => '#{repository[:path]}', :ref => '#{sha}'
END
        case host['platform']
        when /windows/
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          # bundle must be passed a Windows style path for a binstubs location
          bindir = host['puppetbindir'].split(':').first
          binstubs_dir = on(host, "cygpath -m \"#{bindir}\"").stdout.chomp
          # note passing --shebang to bundle is not useful because Cygwin
          # already finds the Ruby interpreter OK with the standard shebang of:
          # !/usr/bin/env ruby
          # the problem is a Cygwin style path is passed to the interpreter and this can't be modified:
          # http://cygwin.1069669.n5.nabble.com/Pass-windows-style-paths-to-the-interpreter-from-the-shebang-line-td43870.html
          on host, "cd #{puppet_dir} && cmd.exe /c \"bundle install --system --binstubs '#{binstubs_dir}'\""
          # puppet.bat isn't written by Bundler, but facter.bat is - copy this generic file
          on host, "cd #{host['puppetbindir']} && test -f ./puppet.bat || cp ./facter.bat ./puppet.bat"
          # to access gem / facter / puppet / bundle / irb with Cygwin generally requires aliases
          # so that commands in /usr/bin are overridden and the binstub wrappers won't run inside Cygwin
          # but rather will execute as batch files through cmd.exe
          # without being overridden, Cygwin reads the shebang and causes errors like:
          # C:\cygwin64\bin\ruby.exe: No such file or directory -- /usr/bin/puppet (LoadError)
          # NOTE /usr/bin/puppet is a Cygwin style path that our custom Ruby build
          # does not understand - it expects a standard Windows path like c:\cygwin64\bin\puppet

          # a workaround in interactive SSH is to add aliases to local session / .bashrc:
          #   on host, "echo \"alias puppet='C:/\\cygwin64/\\bin/\\puppet.bat'\" >> ~/.bashrc"
          # note that this WILL NOT impact Beaker runs though
          puppet_bundler_install_dir = on(host, "cd #{puppet_dir} && cmd.exe /c bundle show puppet").stdout.chomp
        when /el-7/
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents + "gem 'json'\n")
          on host, "cd #{puppet_dir} && bundle install --system --binstubs #{host['puppetbindir']}"
          puppet_bundler_install_dir = on(host, "cd #{puppet_dir} && bundle show puppet").stdout.chomp
        when /solaris/
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          on host, "cd #{puppet_dir} && bundle install --system --binstubs #{host['puppetbindir']} --shebang #{host['puppetbindir']}/ruby"
          puppet_bundler_install_dir = on(host, "cd #{puppet_dir} && bundle show puppet").stdout.chomp
        else
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          on host, "cd #{puppet_dir} && bundle install --system --binstubs #{host['puppetbindir']}"
          puppet_bundler_install_dir = on(host, "cd #{puppet_dir} && bundle show puppet").stdout.chomp
        end

        # install.rb should also be called from the Puppet gem install dir
        # this is required for the puppetres.dll event log dll on Windows
        on host, "cd #{puppet_bundler_install_dir} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi"
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
      codedir = host.puppet['codedir']
      on host, "mkdir -p #{codedir}/environments/production/manifests"
      on host, "mkdir -p #{codedir}/environments/production/modules"
      on host, "chmod -R 755 #{codedir}"
    end
  end
end
