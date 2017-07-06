require 'puppet/provider/package'
require 'fileutils'

Puppet::Type.type(:package).provide :portage, :parent => Puppet::Provider::Package do
  desc "Provides packaging support for Gentoo's portage system."

  has_features :versionable, :reinstallable

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
    slot_versions_format = self.eix_slot_versions_format
    begin
      eix_file = File.directory?("/var/cache/eix") ? "/var/cache/eix/portage.eix" : "/var/cache/eix"
      update_eix if !FileUtils.uptodate?(eix_file, %w{/usr/bin/eix /usr/portage/metadata/timestamp})

      search_output = nil
      Puppet::Util.withenv :LASTVERSION => version_format, :LASTSLOTVERSIONS => slot_versions_format do
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
      name = package_atom_with_version(should)
    end
    emerge name
  end

  # The common package name format.
  def package_name
    @resource[:category] ? "#{@resource[:category]}/#{@resource[:name]}" : @resource[:name]
  end

  def package_name_without_slot
    package_name.sub(self.class.slot_pattern, '')
  end

  def package_slot
    if match = package_name.match(self.class.slot_pattern)
      match[1]
    end
  end

  def package_atom_with_version(version)
    if slot = package_slot
      "=#{package_name_without_slot}-#{version}:#{package_slot}"
    else
      "=#{package_name}-#{version}"
    end
  end

  def uninstall
    emerge "--unmerge", package_name
  end

  def reinstall
    self.install
  end

  def update
    self.install
  end

  def query
    result_format = self.class.eix_result_format
    result_fields = self.class.eix_result_fields

    version_format = self.class.eix_version_format
    slot_versions_format = self.class.eix_slot_versions_format
    search_field = package_name_without_slot.count('/') > 0 ? "--category-name" : "--name"
    search_value = package_name_without_slot

    begin
      eix_file = File.directory?("/var/cache/eix") ? "/var/cache/eix/portage.eix" : "/var/cache/eix"
      update_eix if !FileUtils.uptodate?(eix_file, %w{/usr/bin/eix /usr/portage/metadata/timestamp})

      search_output = nil
      Puppet::Util.withenv :LASTVERSION => version_format, :LASTSLOTVERSIONS => slot_versions_format do
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
          if package_slot
            package[:version_available] = eix_get_version_for_slot(package[:slot_versions_available], package_slot)
            package[:ensure] = eix_get_version_for_slot(package[:installed_slots], package_slot)
          end
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
    self.query[:version_available]
  end

  private
  def eix_get_version_for_slot(versions_and_slots, slot)
    return nil if versions_and_slots.nil?
    versions_and_slots = versions_and_slots.split(",")
    versions_and_slots.map! { |version_and_slot| version_and_slot.split(":") }
    version_for_slot = versions_and_slots.find { |version_and_slot| version_and_slot.last == slot }
    version_for_slot.first if version_for_slot
  end

  def self.slot_pattern
    /:([\w+.\/*=-]+)$/
  end

  def self.eix_search_format
    "'<category> <name> [<installedversions:LASTVERSION>] [<bestversion:LASTVERSION>] [<installedversions:LASTSLOTVERSIONS>] [<bestslotversions:LASTSLOTVERSIONS>] <homepage> <description>\n'"
  end

  def self.eix_result_format
    /^(\S+)\s+(\S+)\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+(\S+)\s+(.*)$/
  end

  def self.eix_result_fields
    [:category, :name, :ensure, :version_available, :installed_slots, :slot_versions_available, :vendor, :description]
  end

  def self.eix_version_format
    "{last}<version>{}"
  end

  def self.eix_slot_versions_format
    "{!first},{}<version>:<slot>"
  end

  def self.eix_search_arguments
    ["--nocolor", "--pure-packages", "--format",self.eix_search_format]
  end
end
