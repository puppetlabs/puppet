# Targetable package providers implement a `command` attribute.
#
# The `packages` hash passed to `Puppet::Provider::Package::prefetch` is deduplicated,
# as it is keyed only by name in `Puppet::Transaction::prefetch_if_necessary`.
#
# (The `packages` hash passed to ``Puppet::Provider::Package::prefetch`` should be keyed by all namevars,
# possibly via a `prefetchV2` method that could take a better data structure.)
#
# In addition, `Puppet::Provider::Package::properties` calls `query` in the provider.
# But `query` in the provider depends upon whether a `command` attribute is defined for the resource.
# This is a Catch-22.
#
# Instead ...
#
# Inspect any package to access the catalog (every package includes a reference to the catalog).
# Inspect the catalog to find all of the `command` attributes for all of the packages of this class.
# Find all of the package instances using each package `command`, including the default provider command.
# Assign each instance's `provider` by selecting it from the `packages` hash passed to `prefetch`, based upon `name` and `command`.
#
# The original `command` parameter in the catalog is not populated by the default (`:default`) for the parameter in type/package.rb.
# Rather, the result of the `original_parameters` is `nil` when the `command` parameter is undefined in the catalog.

class Puppet::Provider::Package::Targetable < Puppet::Provider::Package
  # Prefetch our package list, yo.
  def self.prefetch(packages)
    catalog_packages = packages.first[1]::catalog::resources.select{ |p| p.provider.class == self }
    package_commands = catalog_packages.map { |catalog_package| catalog_package::original_parameters[:command] }.uniq
    package_commands.each do |command|
      instances(command).each do |instance|
        catalog_packages.each do |catalog_package|
          if catalog_package[:name] == instance.name && catalog_package::original_parameters[:command] == command
            catalog_package.provider = instance
            self.debug "Prefetched instance: %{name} via command: %{command}" % { name: instance.name, cmd: (command || :default)}
          end
        end
      end
    end
  end

  # Returns the resource command or provider command.

  def resource_or_provider_command
    resource::original_parameters[:command] || self.class.provider_command
  end

  # Targetable providers use has_command/is_optional to defer validation of provider suitability.
  # Evaluate provider suitability here and now by validating that the command is defined and exists.
  #
  # cmd: the full path to the package command.

  def self.validate_command(cmd)
    unless cmd
      raise Puppet::Error, _("Provider %{name} package command is not functional on this host") % { name: name }
    end
    unless File.file?(cmd)
      raise Puppet::Error, _("Provider %{name} package command '%{cmd}' does not exist on this host") % { name: name, cmd: cmd }
    end
  end

  # Return information about the package, its provider, and its (optional) command.

  def to_s
    cmd = resource[:command] || :default
    "#{@resource}(provider=#{self.class.name})(command=#{cmd})"
  end
end
