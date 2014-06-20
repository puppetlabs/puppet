require 'puppet/provider/package'
require 'fileutils'

Puppet::Type.type(:package).provide :portage, :parent => Puppet::Provider::Package do
  desc "Provides packaging support for Gentoo's portage system."

  VERSION_PATTERN  = '(?:(?:cvs\.)?(?:\d+)(?:(?:\.\d+)*)(?:[a-z]?)(?:(?:_(?:pre|p|beta|alpha|rc)\d*)*)(?:-r(?:\d+))?)'
  SLOT_PATTERN     = '(?:[\w+./*=-]+)'
  VERSION_SLOT_PATTERN = Regexp.new "^(?:(#{VERSION_PATTERN})|:(#{SLOT_PATTERN})|(#{VERSION_PATTERN}):(#{SLOT_PATTERN}))$"

  has_feature :versionable

  {
    :emerge => "/usr/bin/emerge",
    :eix => "/usr/bin/eix",
    :update_eix => "/usr/bin/eix-update",
  }.each_pair do |name, path|
    has_command(name, path) do
      environment :HOME => '/'
    end
  end

  confine :operatingsystem => :gentoo

  defaultfor :operatingsystem => :gentoo

  def self.instances
    result_format = self.eix_result_format
    result_fields = self.eix_result_fields

    version_format = self.eix_version_format
    slot_format = self.eix_slot_format

    begin
      eix_file = File.directory?("/var/cache/eix") ? "/var/cache/eix/portage.eix" : "/var/cache/eix"
      update_eix if !FileUtils.uptodate?(eix_file, %w{/usr/bin/eix /usr/portage/metadata/timestamp})

      search_output = nil
      Puppet::Util.withenv ({ :LASTVERSION => version_format, :LASTSLOT => slot_format }) do
        search_output = eix *(self.eix_search_arguments + ["--installed"])
      end

      packages = []
      search_output.each_line do |search_result|
        match = result_format.match(search_result)

        if match
          package = {}
          result_fields.zip(match.captures) do |field, value|
            package[field] = value unless !value or value.empty?
          end
          package[:ensure] = "#{package[:version_ensure]}:#{package[:slot_ensure]}"
          package[:provider] = :portage
          packages << new(package)
        end
      end

      return packages
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new(detail)
    end
  end

  def install
    should = @resource.should(:ensure)
    name = package_name
    unless should == :present or should == :latest
      # We must install a specific version
      match_group = VERSION_SLOT_PATTERN.match(should)
      if match_group == nil
        raise Puppet::Error.new("Invalid version or slot token: [#{should}]")
      else
        if match_group[3] != nil and match_group[4] != nil
          name = "=#{name}-#{match_group[3]}:#{match_group[4]}" # version:slot
        elsif match_group[1] != nil and match_group[2] == nil
          name = "=#{name}-#{match_group[1]}" # version
        elsif match_group[1] == nil and match_group[2] != nil
          name = "#{name}:#{match_group[2]}"  # slot
        else
          raise Puppet::Error.new("Invalid version or slot token: [#{should}]")
        end
      end
    end
    emerge name
  end

  # The common package name format.
  def package_name
    @resource[:category] ? "#{@resource[:category]}/#{@resource[:name]}" : @resource[:name]
  end

  def uninstall
    emerge "--unmerge", package_name
  end

  def update
    self.install
  end

  def query
    result_format = self.class.eix_result_format
    result_fields = self.class.eix_result_fields

    slot_format = self.class.eix_slot_format
    version_format = self.class.eix_version_format

    search_field = package_name.count('/') > 0 ? "--category-name" : "--name"
    search_value = package_name

    begin
      eix_file = File.directory?("/var/cache/eix") ? "/var/cache/eix/portage.eix" : "/var/cache/eix"
      update_eix if !FileUtils.uptodate?(eix_file, %w{/usr/bin/eix /usr/portage/metadata/timestamp})

      search_output = nil
      Puppet::Util.withenv ({ :LASTVERSION => version_format, :LASTSLOT => slot_format }) do
        search_output = eix *(self.class.eix_search_arguments + ["--exact",search_field,search_value])
      end

      packages = []
      search_output.each_line do |search_result|
        match = result_format.match(search_result)

        if match
          package = {}
          result_fields.zip(match.captures) do |field, value|
            package[field] = value unless !value or value.empty?
          end
          package[:ensure] = "#{package[:version_ensure]}:#{package[:slot_ensure]}"
          package[:ensure] = package[:ensure] ? package[:ensure] : :absent
          packages << package
        end
      end

      case packages.size
        when 0
          not_found_value = "#{@resource[:category] ? @resource[:category] : "<unspecified category>"}/#{@resource[:name]}"
          raise Puppet::Error.new("No package found with the specified name [#{not_found_value}]")
        when 1
          return packages[0]
        else
          raise Puppet::Error.new("More than one package with the specified name [#{search_value}], please use the category parameter to disambiguate")
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new(detail)
    end
  end

  def latest
    version_slot_query = self.query
    "#{version_slot_query[:version_available]}:#{version_slot_query[:slot_available]}"
  end

  private
  def self.eix_search_format
    "'<category> <name> [<installedversions:LASTVERSION>] [<bestversion:LASTVERSION>] [<installedversions:LASTSLOT>] [<bestversion:LASTSLOT>] <homepage> <description>'"
  end

  def self.eix_result_format
    /^(\S+)\s+(\S+)\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+(\S+)\s+(.*)$/
  end

  def self.eix_result_fields
    [:category, :name, :version_ensure, :version_available, :slot_ensure, :slot_available, :vendor, :description]
  end

  def self.eix_version_format
    "{last}<version>{}"
  end

  def self.eix_slot_format
    "{last}<slot>{}"
  end

  def self.eix_search_arguments
    ["--nocolor", "--pure-packages", "--format",self.eix_search_format]
  end
end
