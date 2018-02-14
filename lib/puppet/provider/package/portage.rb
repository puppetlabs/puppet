require 'puppet/provider/package'
require 'fileutils'

Puppet::Type.type(:package).provide :portage, :parent => Puppet::Provider::Package do
  desc "Provides packaging support for Gentoo's portage system.

    This provider supports the `install_options` and `uninstall_options` attributes, which allows command-line
    flags to be passed to emerge.  These options should be specified as a string (e.g. '--flag'), a hash
    (e.g. {'--flag' => 'value'}), or an array where each element is either a string or a hash."

  has_features :install_options, :purgeable, :reinstallable, :uninstall_options, :versionable, :virtual_packages

  {
    :emerge => '/usr/bin/emerge',
    :eix => '/usr/bin/eix',
    :qatom_bin => '/usr/bin/qatom',
    :update_eix => '/usr/bin/eix-update',
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

    limit = self.eix_limit
    version_format = self.eix_version_format
    slot_versions_format = self.eix_slot_versions_format
    installed_versions_format = self.eix_installed_versions_format
    installable_versions_format = self.eix_install_versions_format
    begin
      eix_file = File.directory?('/var/cache/eix') ? '/var/cache/eix/portage.eix' : '/var/cache/eix'
      update_eix if !FileUtils.uptodate?(eix_file, %w{/usr/bin/eix /usr/portage/metadata/timestamp})

      search_output = nil
      Puppet::Util.withenv :EIX_LIMIT => limit, :LASTVERSION => version_format, :LASTSLOTVERSIONS => slot_versions_format, :INSTALLEDVERSIONS => installed_versions_format, :STABLEVERSIONS => installable_versions_format do
        search_output = eix(*(self.eix_search_arguments + ['--installed']))
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
    cmd = %w{}
    name = qatom[:category] ? "#{qatom[:category]}/#{qatom[:pn]}" : qatom[:pn]
    name = qatom[:pfx] + name if qatom[:pfx]
    name = name + '-' + qatom[:pv] if qatom[:pv]
    name = name + '-' + qatom[:pr] if qatom[:pr]
    name = name + qatom[:slot] if qatom[:slot]
    cmd << '--update' if [:latest].include?(should)
    cmd += install_options if @resource[:install_options]
    cmd << name
    emerge(*cmd)
  end

  def uninstall
    should = @resource.should(:ensure)
    cmd = %w{--rage-clean}
    name = qatom[:category] ? "#{qatom[:category]}/#{qatom[:pn]}" : qatom[:pn]
    name = qatom[:pfx] + name if qatom[:pfx]
    name = name + '-' + qatom[:pv] if qatom[:pv]
    name = name + '-' + qatom[:pr] if qatom[:pr]
    name = name + qatom[:slot] if qatom[:slot]
    cmd += uninstall_options if @resource[:uninstall_options]
    cmd << name
    if [:purged].include?(should)
      Puppet::Util.withenv :CONFIG_PROTECT => "-*" do
        emerge(*cmd)
      end
    else
      emerge(*cmd)
    end
  end

  def reinstall
    self.install
  end

  def update
    self.install
  end

  def qatom
    output_format = self.qatom_output_format
    result_format = self.qatom_result_format
    result_fields = self.qatom_result_fields
    @atom ||= begin
      package_info = {}
      # do the search
      search_output = qatom_bin(*([@resource[:name], '--format', output_format]))
      # verify if the search found anything
      match = result_format.match(search_output)
      if match
        result_fields.zip(match.captures) do |field, value|
          # some fields can be empty or (null) (if we are not passed a category in the package name for instance)
          if value == '(null)'
            package_info[field] = nil
          elsif !value or value.empty?
            package_info[field] = nil
          else
            package_info[field] = value
          end
        end
      end
      @atom = package_info
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new(detail)
    end
  end

  def qatom_output_format
    '"[%{CATEGORY}] [%{PN}] [%{PV}] [%[PR]] [%[SLOT]] [%[pfx]] [%[sfx]]"'
  end

  def qatom_result_format
    /^\"\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\](.*)\"$/
  end

  def qatom_result_fields
    [:category, :pn, :pv, :pr, :slot, :pfx, :sfx]
  end

  def self.get_sets
    @sets ||= begin
      @sets = emerge(*(['--list-sets']))
    end
  end

  def query
    limit = self.class.eix_limit
    result_format = self.class.eix_result_format
    result_fields = self.class.eix_result_fields

    version_format = self.class.eix_version_format
    slot_versions_format = self.class.eix_slot_versions_format
    installed_versions_format = self.class.eix_installed_versions_format
    installable_versions_format = self.class.eix_install_versions_format
    search_field = qatom[:category] ? '--category-name' : '--name'
    search_value = qatom[:category] ? "#{qatom[:category]}/#{qatom[:pn]}" : qatom[:pn]

    @eix_result ||= begin
      # package sets
      package_sets = []
      self.class.get_sets.each_line do |package_set|
        package_sets << package_set.to_s.strip
      end

      if @resource[:name].match(/^@/)
        if package_sets.include?(@resource[:name][1..-1].to_s)
          return({:name => "#{@resource[:name]}", :ensure => '9999', :version_available => nil, :installed_versions => nil, :installable_versions => "9999,"})
        end
      end

      eix_file = File.directory?('/var/cache/eix') ? '/var/cache/eix/portage.eix' : '/var/cache/eix'
      update_eix if !FileUtils.uptodate?(eix_file, %w{/usr/bin/eix /usr/portage/metadata/timestamp})

      search_output = nil
      Puppet::Util.withenv :EIX_LIMIT => limit, :LASTVERSION => version_format, :LASTSLOTVERSIONS => slot_versions_format, :INSTALLEDVERSIONS => installed_versions_format, :STABLEVERSIONS => installable_versions_format do
        search_output = eix(*(self.class.eix_search_arguments + ['--exact',search_field,search_value]))
      end

      packages = []
      search_output.each_line do |search_result|
        match = result_format.match(search_result)

        if match
          package = {}
          result_fields.zip(match.captures) do |field, value|
            package[field] = value unless !value or value.empty?
          end
          # dev-lang python [3.4.5] [3.5.2] [2.7.12:2.7,3.4.5:3.4] [2.7.12:2.7,3.4.5:3.4,3.5.2:3.5] https://www.python.org/ An interpreted, interactive, object-oriented programming language
          # version_available is what we CAN install / update to
          # ensure is what is currently installed
          # This DOES NOT choose to install/upgrade or not, just provides current info
          # prefer checking versions to slots as versions are finer grained
          if qatom[:pv]
            package[:version_available] = eix_get_version_for_versions(package[:installable_versions], qatom[:pv])
            package[:ensure] = eix_get_version_for_versions(package[:installed_versions], qatom[:pv])
          elsif qatom[:slot]
            package[:version_available] = eix_get_version_for_slot(package[:slot_versions_available], qatom[:slot])
            package[:ensure] = eix_get_version_for_slot(package[:installed_slots], qatom[:slot])
          end

          package[:ensure] = package[:ensure] ? package[:ensure] : :absent
          packages << package
        end
      end

      case packages.size
        when 0
          raise Puppet::Error.new(_("No package found with the specified name [%{name}]") % { name: @resource[:name] })
        when 1
          @eix_result = packages[0]
        else
          raise Puppet::Error.new(_("More than one package with the specified name [%{search_value}], please use the category parameter to disambiguate") % { search_value: search_value })
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new(detail)
    end
  end

  def latest
    self.query[:version_available]
  end

  private
  def eix_get_version_for_versions(versions, target)
    # [2.7.10-r1,2.7.12,3.4.3-r1,3.4.5,3.5.2] 3.5.2
    return nil if versions.nil?
    versions = versions.split(',')
    # [2.7.10-r1 2.7.12 3.4.3-r1 3.4.5 3.5.2]
    versions.find { |version| version == target }
    # 3.5.2
  end

  private
  def eix_get_version_for_slot(versions_and_slots, slot)
    # [2.7.12:2.7 3.4.5:3.4 3.5.2:3.5] 3.5
    return nil if versions_and_slots.nil?
    versions_and_slots = versions_and_slots.split(',')
    # [2.7.12:2.7 3.4.5:3.4 3.5.2:3.5]
    versions_and_slots.map! { |version_and_slot| version_and_slot.split(':') }
    # [2.7.12: 2.7
    #  3.4.5:  3.4
    #  3.5.2:  3.5]
    version_for_slot = versions_and_slots.find { |version_and_slot| version_and_slot.last == slot[1..-1] }
    # [3.5.2:  3.5]
    version_for_slot.first if version_for_slot
    # 3.5.2
  end

  def self.eix_search_format
    "'<category> <name> [<installedversions:LASTVERSION>] [<bestversion:LASTVERSION>] [<installedversions:LASTSLOTVERSIONS>] [<installedversions:INSTALLEDVERSIONS>] [<availableversions:STABLEVERSIONS>] [<bestslotversions:LASTSLOTVERSIONS>] <homepage> <description>\n'"
  end

  def self.eix_result_format
    /^(\S+)\s+(\S+)\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+\[(\S*)\]\s+(\S+)\s+(.*)$/
  end

  def self.eix_result_fields
    # ensure:[3.4.5], version_available:[3.5.2], installed_slots:[2.7.12:2.7,3.4.5:3.4], installable_versions:[2.7.10-r1,2.7.12,3.4.3-r1,3.4.5,3.5.2] slot_versions_available:[2.7.12:2.7,3.4.5:3.4,3.5.2:3.5]
    [:category, :name, :ensure, :version_available, :installed_slots, :installed_versions, :installable_versions, :slot_versions_available, :vendor, :description]
  end

  def self.eix_version_format
    '{last}<version>{}'
  end

  def self.eix_slot_versions_format
    '{!first},{}<version>:<slot>'
  end

  def self.eix_installed_versions_format
    '{!first},{}<version>'
  end

  def self.eix_install_versions_format
    '{!first}{!last},{}{}{isstable}<version>{}'
  end

  def self.eix_limit
    '0'
  end

  def self.eix_search_arguments
    ['--nocolor', '--pure-packages', '--format', self.eix_search_format]
  end

  def install_options
    join_options(@resource[:install_options])
  end

  def uninstall_options
    join_options(@resource[:uninstall_options])
  end
end
