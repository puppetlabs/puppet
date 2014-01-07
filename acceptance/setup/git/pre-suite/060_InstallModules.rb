require 'pathname'

# Given an array of modules specified by the --modules command line option,
# Parse all of them into an array of usable hash structures.
class PuppetModules
  attr_reader :modules

  def initialize(modules=[])
    @modules = modules
  end

  def list
    return [] unless modules
    modules.collect do |uri|
      git_url, git_ref = uri.split '#'
      folder = Pathname.new(git_url).basename('.git')
      name = folder.to_s.split('-', 2)[1] || folder.to_s
      {
        :name     => name,
        :url      => git_url,
        :folder   => folder.to_s,
        :ref      => git_ref,
        :protocol => git_url.split(':')[0].intern,
      }
    end
  end
end

def install_git_module(mod, hosts)
  # The idea here is that each test can symlink the modules they want from a
  # temporary directory to this location.  This will preserve the global
  # state of the system while allowing individual test cases to quickly run
  # with a module "installed" in the module path.
  moddir = "/opt/puppet-git-repos"
  target = "#{moddir}/#{mod[:name]}"

  step "Clone #{mod[:url]} if needed"
  on hosts, "test -d #{moddir} || mkdir -p #{moddir}"
  on hosts, "test -d #{target} || git clone #{mod[:url]} #{target}"
  step "Update #{mod[:name]} and check out revision #{mod[:ref]}"

  commands = ["cd #{target}",
              "remote rm origin",
              "remote add origin #{mod[:url]}",
              "fetch origin",
              "checkout -f #{mod[:ref]}",
              "reset --hard refs/remotes/origin/#{mod[:ref]}",
              "clean -fdx",
  ]

  on hosts, commands.join(" && git ")
end

def install_scp_module(mod, hosts)
  moddir = "/opt/puppet-git-repos"
  target = "#{moddir}/#{mod[:name]}"

  step "Purge #{target} if needed"
  on hosts, "test -d #{target} && rm -rf #{target} || true"

  step "Copy #{mod[:name]} to hosts"
  scp_to hosts, mod[:url].split(':', 2)[1], target
end

modules = PuppetModules.new(options[:modules]).list

step "Masters: Install Puppet Modules"
masters = hosts.select { |host| host['roles'].include? 'master' }

modules.each do |mod|
  if mod[:protocol] == :scp
    install_scp_module(mod, masters)
  else
    install_git_module(mod, masters)
  end
end
