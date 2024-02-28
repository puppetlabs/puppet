# frozen_string_literal: true

unless Puppet::Util::Platform.jruby_fips?
  require 'rubygems/commands/list_command'
end
require 'stringio'
require 'uri'

# Ruby gems support.
Puppet::Type.type(:package).provide :puppetserver_gem, :parent => :gem do
  desc "Puppet Server Ruby Gem support. If a URL is passed via `source`, then
    that URL is appended to the list of remote gem repositories which by default
    contains rubygems.org; To ensure that only the specified source is used also
    pass `--clear-sources` in via `install_options`; if a source is present but
    is not a valid URL, it will be interpreted as the path to a local gem file.
    If source is not present at all, the gem will be installed from the default
    gem repositories."

  has_feature :versionable, :install_options, :uninstall_options

  confine :feature => :hocon
  # see SERVER-2578
  confine :fips_enabled => false

  # Define the default provider package command name, as the parent 'gem' provider is targetable.
  # Required by Puppet::Provider::Package::Targetable::resource_or_provider_command

  def self.provider_command
    command(:puppetservercmd)
  end

  # The gem command uses HOME to locate a gemrc file.
  # CommandDefiner in provider.rb will set failonfail, combine, and environment.

  has_command(:puppetservercmd, '/opt/puppetlabs/bin/puppetserver') do
    environment(HOME: ENV.fetch('HOME', nil))
  end

  def self.gemlist(options)
    command_options = ['gem', 'list']

    if options[:local]
      command_options << '--local'
    else
      command_options << '--remote'
    end

    if options[:source]
      command_options << '--source' << options[:source]
    end

    if options[:justme]
      gem_regex = '\A' + options[:justme] + '\z'
      command_options << gem_regex
    end

    if options[:local]
      list = execute_rubygems_list_command(command_options)
    else
      begin
        list = puppetservercmd(command_options)
      rescue Puppet::ExecutionFailure => detail
        raise Puppet::Error, _("Could not list gems: %{detail}") % { detail: detail }, detail.backtrace
      end
    end

    # When `/tmp` is mounted `noexec`, `puppetserver gem list` will output:
    # *** LOCAL GEMS ***
    # causing gemsplit to output:
    # Warning: Could not match *** LOCAL GEMS ***
    gem_list = list
               .lines
               .select { |x| x =~ /^(\S+)\s+\((.+)\)/ }
               .map { |set| gemsplit(set) }

    if options[:justme]
      return gem_list.shift
    else
      return gem_list
    end
  end

  def install(useversion = true)
    command_options = ['gem', 'install']
    command_options += install_options if resource[:install_options]

    command_options << '-v' << resource[:ensure] if (!resource[:ensure].is_a? Symbol) && useversion

    command_options << '--no-document'

    if resource[:source]
      begin
        uri = URI.parse(resource[:source])
      rescue => detail
        self.fail Puppet::Error, _("Invalid source '%{uri}': %{detail}") % { uri: uri, detail: detail }, detail
      end

      case uri.scheme
      when nil
        # no URI scheme => interpret the source as a local file
        command_options << resource[:source]
      when /file/i
        command_options << uri.path
      when 'puppet'
        # we don't support puppet:// URLs (yet)
        raise Puppet::Error, _('puppet:// URLs are not supported as gem sources')
      else
        # interpret it as a gem repository
        command_options << '--source' << "#{resource[:source]}" << resource[:name]
      end
    else
      command_options << resource[:name]
    end

    output = puppetservercmd(command_options)
    # Apparently, some gem versions don't exit non-0 on failure.
    self.fail _("Could not install: %{output}") % { output: output.chomp } if output.include?('ERROR')
  end

  def uninstall
    command_options = ['gem', 'uninstall']
    command_options << '--executables' << '--all' << resource[:name]
    command_options += uninstall_options if resource[:uninstall_options]

    output = puppetservercmd(command_options)
    # Apparently, some gem versions don't exit non-0 on failure.
    self.fail _("Could not uninstall: %{output}") % { output: output.chomp } if output.include?('ERROR')
  end

  private

  # The puppetserver gem cli command is very slow, since it starts a JVM.
  #
  # Instead, for the list subcommand (which is executed with every puppet run),
  # use the rubygems library from puppet ruby: setting GEM_HOME and GEM_PATH
  # to the default values, or the values in the puppetserver configuration file.
  #
  # The rubygems library cannot access java platform gems,
  # for example: json (1.8.3 java)
  # but java platform gems should not be managed by this (or any) provider.

  def self.execute_rubygems_list_command(command_options)
    puppetserver_default_gem_home            = '/opt/puppetlabs/server/data/puppetserver/jruby-gems'
    puppetserver_default_vendored_jruby_gems = '/opt/puppetlabs/server/data/puppetserver/vendored-jruby-gems'
    puppet_default_vendor_gems               = '/opt/puppetlabs/puppet/lib/ruby/vendor_gems'
    puppetserver_default_gem_path = [puppetserver_default_gem_home, puppetserver_default_vendored_jruby_gems, puppet_default_vendor_gems].join(':')

    pe_puppetserver_conf_file = '/etc/puppetlabs/puppetserver/conf.d/pe-puppet-server.conf'
    os_puppetserver_conf_file = '/etc/puppetlabs/puppetserver/puppetserver.conf'
    puppetserver_conf_file = Puppet.runtime[:facter].value(:pe_server_version) ? pe_puppetserver_conf_file : os_puppetserver_conf_file
    puppetserver_conf = Hocon.load(puppetserver_conf_file)

    gem_env = {}
    if puppetserver_conf.empty? || puppetserver_conf.key?('jruby-puppet') == false
      gem_env['GEM_HOME'] = puppetserver_default_gem_home
      gem_env['GEM_PATH'] = puppetserver_default_gem_path
    else
      gem_env['GEM_HOME'] = puppetserver_conf['jruby-puppet'].key?('gem-home') ? puppetserver_conf['jruby-puppet']['gem-home'] : puppetserver_default_gem_home
      gem_env['GEM_PATH'] = puppetserver_conf['jruby-puppet'].key?('gem-path') ? puppetserver_conf['jruby-puppet']['gem-path'].join(':') : puppetserver_default_gem_path
    end
    gem_env['GEM_SPEC_CACHE'] = "/tmp/#{$$}"

    # Remove the 'gem' from the command_options
    command_options.shift
    gem_out = execute_gem_command(Puppet::Type::Package::ProviderPuppet_gem.provider_command, command_options, gem_env)

    # There is no method exclude default gems from the local gem list,
    # for example: psych (default: 2.2.2)
    # but default gems should not be managed by this (or any) provider.
    gem_list = gem_out.lines.reject { |gem| gem =~ / \(default\: / }
    gem_list.join("\n")
  end
end
