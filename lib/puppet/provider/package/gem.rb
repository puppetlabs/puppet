require 'puppet/provider/package'
require 'uri'

# Ruby gems support.
Puppet::Type.type(:package).provide :gem, :parent => Puppet::Provider::Package do
  desc "Ruby Gem support.  If a URL is passed via `source`, then that URL is used as the
    remote gem repository; if a source is present but is not a valid URL, it will be
    interpreted as the path to a local gem file.  If source is not present at all,
    the gem will be installed from the default gem repositories.

    This provider supports the `install_options` and `uninstall_options` attributes,
    which allow command-line flags to be passed to the gem command.
    These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
    or an array where each element is either a string or a hash."

  has_feature :versionable, :install_options, :uninstall_options

  def self.which_windows_gemcmd(bin)
    # On Windows, the puppet ruby bin dir is prepended to the system PATH.
    # This custom which() method skips that path. Refer to util.rb for the standard method.
    # (Use puppet_gem to manage gems needed by the ruby provided in the puppet-agent package.)
    exts = Puppet::Util.get_env('PATHEXT')
    exts = exts ? exts.split(File::PATH_SEPARATOR) : %w[.COM .EXE .BAT .CMD]
    puppet_ruby_bin_dir = File.join(Puppet::Util.get_env('RUBY_DIR'),'bin')
    puppet_ruby_bin_dir.gsub!(File::SEPARATOR,File::ALT_SEPARATOR)
    Puppet::Util.get_env('PATH').split(File::PATH_SEPARATOR).each do |dir|
      if dir == puppet_ruby_bin_dir
        # Skip this path if it is the puppet ruby bin dir.
        next
      end
      begin
        dest = File.expand_path(File.join(dir, bin))
      rescue ArgumentError => e
        # If the user's PATH contains a literal tilde (~) character and HOME is not set, we may get an ArgumentError here.
        # Let's check to see if that is the case; if not, re-raise whatever error was thrown.
        if e.to_s =~ /HOME/ and (Puppet::Util.get_env('HOME').nil? || Puppet::Util.get_env('HOME') == "")
          # If we get here, then they have a tilde in their PATH.
          # We'll issue a single warning about this, and then ignore this path element and carry on with our lives.
          Puppet::Util::Warnings.warnonce("PATH contains a ~ character, and HOME is not set; ignoring PATH element '#{dir}'.")
        elsif e.to_s =~ /doesn't exist|can't find user/
          # Otherwise, we just skip the non-existent entry, and do nothing.
          Puppet::Util::Warnings.warnonce("Couldn't expand PATH containing a ~ character; ignoring PATH element '#{dir}'.")
        else
          raise
        end
      else
        if File.extname(dest).empty?
          exts.each do |ext|
            dest_ext = File.expand_path(dest + ext)
            return dest_ext if FileTest.file? dest_ext and FileTest.executable? dest_ext
          end
        end
        return dest if FileTest.file? dest and FileTest.executable? dest
      end
    end
    return nil
  end

  if Puppet.features.microsoft_windows?
    commands :gemcmd => self.which_windows_gemcmd("gem")
  else
    commands :gemcmd => "gem"
  end

  def self.gemlist(options)
    gem_list_command = [command(:gemcmd), "list"]

    if options[:local]
      gem_list_command << "--local"
    else
      gem_list_command << "--remote"
    end
    if options[:source]
      gem_list_command << "--source" << options[:source]
    end
    if name = options[:justme]
      gem_list_command << "^" + name + "$"
    end

    begin
      list = execute(gem_list_command).lines.
        map {|set| gemsplit(set) }.
        reject {|x| x.nil? }
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not list gems: #{detail}", detail.backtrace
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
      gem_name = $1
      versions = $2.split(/,\s*/)
      {
        :name     => gem_name,
        :ensure   => versions.map{|v| v.split[0]},
        :provider => name
      }
    else
      Puppet.warning "Could not match #{desc}" unless desc.chomp.empty?
      nil
    end
  end

  def self.instances(justme = false)
    gemlist(:local => true).collect do |hash|
      new(hash)
    end
  end

  def insync?(is)
    return false unless is && is != :absent

    begin
      dependency = Gem::Dependency.new('', resource[:ensure])
    rescue ArgumentError
      # Bad requirements will cause an error during gem command invocation, so just return not in sync
      return false
    end

    is = [is] unless is.is_a? Array

    # Check if any version matches the dependency
    is.any? { |version| dependency.match?('', version) }
  end

  def install(useversion = true)
    command = [command(:gemcmd), "install"]
    if Puppet.features.microsoft_windows?
      version = resource[:ensure]
      command << "-v" << %Q["#{version}"] if (! resource[:ensure].is_a? Symbol) and useversion
    else
      command << "-v" << resource[:ensure] if (! resource[:ensure].is_a? Symbol) and useversion
    end

    if source = resource[:source]
      begin
        uri = URI.parse(source)
      rescue => detail
        self.fail Puppet::Error, "Invalid source '#{uri}': #{detail}", detail
      end

      case uri.scheme
      when nil
        # no URI scheme => interpret the source as a local file
        command << source
      when /file/i
        command << uri.path
      when 'puppet'
        # we don't support puppet:// URLs (yet)
        raise Puppet::Error.new("puppet:// URLs are not supported as gem sources")
      else
        # check whether it's an absolute file path to help Windows out
        if Puppet::Util.absolute_path?(source)
          command << source
        else
          # interpret it as a gem repository
          command << "--source" << "#{source}" << resource[:name]
        end
      end
    else
      command << "--no-rdoc" << "--no-ri" << resource[:name]
    end

    command += install_options if resource[:install_options]

    output = execute(command)
    # Apparently some stupid gem versions don't exit non-0 on failure
    self.fail "Could not install: #{output.chomp}" if output.include?("ERROR")
  end

  def latest
    # This always gets the latest version available.
    gemlist_options = {:justme => resource[:name]}
    gemlist_options.merge!({:source => resource[:source]}) unless resource[:source].nil?
    hash = self.class.gemlist(gemlist_options)

    hash[:ensure][0]
  end

  def query
    self.class.gemlist(:justme => resource[:name], :local => true)
  end

  def uninstall
    command = [command(:gemcmd), "uninstall"]
    command << "--executables" << "--all" << resource[:name]

    command += uninstall_options if resource[:uninstall_options]

    output = execute(command)

    # Apparently some stupid gem versions don't exit non-0 on failure
    self.fail "Could not uninstall: #{output.chomp}" if output.include?("ERROR")
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
