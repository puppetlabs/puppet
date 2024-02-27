# frozen_string_literal: true

require_relative '../../../puppet/util/package/version/gem'
require_relative '../../../puppet/util/package/version/range'
require_relative '../../../puppet/provider/package_targetable'
require 'uri'

# Ruby gems support.
Puppet::Type.type(:package).provide :gem, :parent => Puppet::Provider::Package::Targetable do
  desc "Ruby Gem support. If a URL is passed via `source`, then that URL is
    appended to the list of remote gem repositories; to ensure that only the
    specified source is used, also pass `--clear-sources` via `install_options`.
    If source is present but is not a valid URL, it will be interpreted as the
    path to a local gem file. If source is not present, the gem will be
    installed from the default gem repositories. Note that to modify this for Windows, it has to be a valid URL.

    This provider supports the `install_options` and `uninstall_options` attributes,
    which allow command-line flags to be passed to the gem command.
    These options should be specified as an array where each element is either a
    string or a hash."

  has_feature :versionable, :install_options, :uninstall_options, :targetable, :version_ranges

  GEM_VERSION =       Puppet::Util::Package::Version::Gem
  GEM_VERSION_RANGE = Puppet::Util::Package::Version::Range

  # Override the specificity method to return 1 if gem is not set as default provider
  def self.specificity
    match = default_match
    length = match ? match.length : 0

    return 1 if length == 0

    super
  end

  # Define the default provider package command name when the provider is targetable.
  # Required by Puppet::Provider::Package::Targetable::resource_or_provider_command

  def self.provider_command
    if Puppet::Util::Platform.windows?
      Puppet::Util.withenv(PATH: windows_path_without_puppet_bin) { command(:gemcmd) }
    else
      command(:gemcmd)
    end
  end

  # Define the default provider package command as optional when the provider is targetable.
  # Doing do defers the evaluation of provider suitability until all commands are evaluated.

  has_command(:gemcmd, 'gem') do
    is_optional
  end

  # Having puppet/bin in PATH makes gem provider to use puppet/bin/gem
  # This is an utility methods that reads the PATH and returns a string
  # that contains the content of PATH but without puppet/bin dir.
  # This is used to pass a custom PATH and execute commands in a controlled environment
  def self.windows_path_without_puppet_bin
    # rubocop:disable Naming/MemoizedInstanceVariableName
    @path ||= ENV['PATH'].split(File::PATH_SEPARATOR)
                         .reject { |dir| dir =~ /puppet\\bin$/ }
                         .join(File::PATH_SEPARATOR)
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end

  private_class_method :windows_path_without_puppet_bin

  # CommandDefiner in provider.rb creates convenience execution methods that set failonfail, combine, and optionally, environment.
  # And when a child provider defines its own command via commands() or has_command(), the provider-specific path is always returned by command().
  # But when the convenience execution method is invoked, the last convenience method to be defined is executed.
  # This makes invoking those convenience execution methods unsuitable for inherited providers.
  #
  # In this case, causing the puppet_gem provider to inherit the parent gem provider's convenience gemcmd() methods, with the wrong path.

  def self.execute_gem_command(command, command_options, custom_environment = {})
    validate_command(command)
    cmd = [command] << command_options

    custom_environment = { 'HOME' => ENV.fetch('HOME', nil) }.merge(custom_environment)

    if Puppet::Util::Platform.windows?
      custom_environment[:PATH] = windows_path_without_puppet_bin
    end

    execute(cmd, { :failonfail => true, :combine => true, :custom_environment => custom_environment })
  end

  def self.instances(target_command = nil)
    if target_command
      command = target_command
    else
      command = provider_command
      # The default provider package command is optional.
      return [] unless command
    end

    gemlist(:command => command, :local => true).collect do |pkg|
      # Track the command when the provider is targetable.
      pkg[:command] = command
      new(pkg)
    end
  end

  def self.gemlist(options)
    command_options = ["list"]

    if options[:local]
      command_options << "--local"
    else
      command_options << "--remote"
    end
    if options[:source]
      command_options << "--source" << options[:source]
    end
    name = options[:justme]
    if name
      command_options << '\A' + name + '\z'
    end

    begin
      list = execute_gem_command(options[:command], command_options).lines
                                                                    .filter_map { |set| gemsplit(set) }
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Could not list gems: %{detail}") % { detail: detail }, detail.backtrace
    end

    if options[:justme]
      return list.shift
    else
      return list
    end
  end

  def self.gemsplit(desc)
    # `gem list` when output console has a line like:
    # *** LOCAL GEMS ***
    # but when it's not to the console that line
    # and all blank lines are stripped
    # so we don't need to check for them

    if desc =~ /^(\S+)\s+\((.+)\)/
      gem_name = Regexp.last_match(1)
      versions = Regexp.last_match(2).sub('default: ', '').split(/,\s*/)
      {
        :name => gem_name,
        :ensure => versions.map { |v| v.split[0] },
        :provider => name
      }
    else
      Puppet.warning _("Could not match %{desc}") % { desc: desc } unless desc.chomp.empty?
      nil
    end
  end

  def insync?(is)
    return false unless is && is != :absent

    is = [is] unless is.is_a? Array
    should = @resource[:ensure]

    unless should =~ Regexp.union(/,/, Gem::Requirement::PATTERN)
      begin
        should_range = GEM_VERSION_RANGE.parse(should, GEM_VERSION)
      rescue GEM_VERSION_RANGE::ValidationFailure, GEM_VERSION::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a ruby gem version range")
        return false
      end

      return is.any? do |version|
        begin
          should_range.include?(GEM_VERSION.parse(version))
        rescue GEM_VERSION::ValidationFailure
          Puppet.debug("Cannot parse #{version} as a ruby gem version")
          false
        end
      end
    end

    begin
      # Range intersections are not supported by Gem::Requirement, so just split by comma.
      dependency = Gem::Dependency.new('', should.split(','))
    rescue ArgumentError
      # Bad requirements will cause an error during gem command invocation, so just return not in sync
      return false
    end

    # Check if any version matches the dependency
    is.any? { |version| dependency.match?('', version) }
  end

  def rubygem_version(command)
    command_options = ["--version"]
    self.class.execute_gem_command(command, command_options)
  end

  def install(useversion = true)
    command = resource_or_provider_command
    command_options = ["install"]
    command_options += install_options if resource[:install_options]
    should = resource[:ensure]

    unless should =~ Regexp.union(/,/, Gem::Requirement::PATTERN)
      begin
        should_range = GEM_VERSION_RANGE.parse(should, GEM_VERSION)
        should = should_range.to_gem_version
        useversion = true
      rescue GEM_VERSION_RANGE::ValidationFailure, GEM_VERSION::ValidationFailure
        Puppet.debug("Cannot parse #{should} as a ruby gem version range. Falling through.")
      end
    end

    if Puppet::Util::Platform.windows?
      command_options << "-v" << %Q("#{should}") if useversion && !should.is_a?(Symbol)
    elsif useversion && !should.is_a?(Symbol)
      command_options << "-v" << should
    end

    if Puppet::Util::Package.versioncmp(rubygem_version(command), '2.0.0') == -1
      command_options << "--no-rdoc" << "--no-ri"
    else
      command_options << "--no-document"
    end

    source = resource[:source]
    if source
      begin
        uri = URI.parse(source)
      rescue => detail
        self.fail Puppet::Error, _("Invalid source '%{uri}': %{detail}") % { uri: uri, detail: detail }, detail
      end

      case uri.scheme
      when nil
        # no URI scheme => interpret the source as a local file
        command_options << source
      when /file/i
        command_options << uri.path
      when 'puppet'
        # we don't support puppet:// URLs (yet)
        raise Puppet::Error.new(_("puppet:// URLs are not supported as gem sources"))
      else
        # check whether it's an absolute file path to help Windows out
        if Puppet::Util.absolute_path?(source)
          command_options << source
        else
          # interpret it as a gem repository
          command_options << "--source" << "#{source}" << resource[:name]
        end
      end
    else
      command_options << resource[:name]
    end

    output = self.class.execute_gem_command(command, command_options)
    # Apparently some gem versions don't exit non-0 on failure.
    self.fail _("Could not install: %{output}") % { output: output.chomp } if output.include?("ERROR")
  end

  def latest
    command = resource_or_provider_command
    options = { :command => command, :justme => resource[:name] }
    options[:source] = resource[:source] unless resource[:source].nil?
    pkg = self.class.gemlist(options)
    pkg[:ensure][0]
  end

  def query
    command = resource_or_provider_command
    options = { :command => command, :justme => resource[:name], :local => true }
    pkg = self.class.gemlist(options)
    pkg[:command] = command unless pkg.nil?
    pkg
  end

  def uninstall
    command = resource_or_provider_command
    command_options = ["uninstall"]
    command_options << "--executables" << "--all" << resource[:name]
    command_options += uninstall_options if resource[:uninstall_options]
    output = self.class.execute_gem_command(command, command_options)
    # Apparently some gem versions don't exit non-0 on failure.
    self.fail _("Could not uninstall: %{output}") % { output: output.chomp } if output.include?("ERROR")
  end

  def update
    self.install(false)
  end

  def install_options
    join_options(resource[:install_options])
  end

  def uninstall_options
    join_options(resource[:uninstall_options])
  end
end
