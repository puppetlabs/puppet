require 'yaml'
require 'puppet/util/yaml'

# A persistence store implementation for storing information between
# transaction runs for the purposes of information inference (such
# as calculating corrective_change).
# @api private
class Puppet::Transaction::Persistence
  def initialize
    @old_data = {}
    @new_data = {"resources" => {}}
  end

  # Obtain the full raw data from the persistence store.
  # @return [Hash] hash of data stored in persistence store
  def data
    @old_data
  end

  # Retrieve the system value using the resource and parameter name
  # @param [String] resource_name name of resource
  # @param [String] param_name name of the parameter
  # @return [Object,nil] the system_value
  def get_system_value(resource_name, param_name)
    if !@old_data["resources"].nil? &&
       !@old_data["resources"][resource_name].nil? &&
       !@old_data["resources"][resource_name]["parameters"].nil? &&
       !@old_data["resources"][resource_name]["parameters"][param_name].nil?
      @old_data["resources"][resource_name]["parameters"][param_name]["system_value"]
    else
      nil
    end
  end

  def set_system_value(resource_name, param_name, value)
    @new_data["resources"] ||= {}
    @new_data["resources"][resource_name] ||= {}
    @new_data["resources"][resource_name]["parameters"] ||= {}
    @new_data["resources"][resource_name]["parameters"][param_name] ||= {}
    @new_data["resources"][resource_name]["parameters"][param_name]["system_value"] = value
  end

  def copy_skipped(resource_name)
    @old_data["resources"] ||= {}
    old_value = @old_data["resources"][resource_name]
    if !old_value.nil?
      @new_data["resources"][resource_name] = old_value
    end
  end

  # Load data from the persistence store on disk.
  def load
    filename = Puppet[:transactionstorefile]
    unless Puppet::FileSystem.exist?(filename)
      return
    end
    unless File.file?(filename)
      Puppet.warning(_("Transaction store file %{filename} is not a file, ignoring") % { filename: filename })
      return
    end

    result = nil
    Puppet::Util.benchmark(:debug, _("Loaded transaction store file in %{seconds} seconds")) do
      begin
        result = Puppet::Util::Yaml.load_file(filename, false, true)
      rescue Puppet::Util::Yaml::YamlLoadError => detail
        Puppet.log_exception(detail, _("Transaction store file %{filename} is corrupt (%{detail}); replacing") % { filename: filename, detail: detail }, { :level => :warning })

        begin
          File.rename(filename, filename + ".bad")
        rescue => detail
          Puppet.log_exception(detail, _("Unable to rename corrupt transaction store file: %{detail}") % { detail: detail })
          raise Puppet::Error, _("Could not rename corrupt transaction store file %{filename}; remove manually") % { filename: filename }, detail.backtrace
        end

        result = {}
      end
    end

    unless result.is_a?(Hash)
      Puppet.err _("Transaction store file %{filename} is valid YAML but not returning a hash. Check the file for corruption, or remove it before continuing.") % { filename: filename }
      return
    end

    @old_data = result
  end

  # Save data from internal class to persistence store on disk.
  def save
    Puppet::Util::Yaml.dump(@new_data, Puppet[:transactionstorefile])
  end

  # Use the catalog and run_mode to determine if persistence should be enabled or not
  # @param [Puppet::Resource::Catalog] catalog catalog being processed
  # @return [boolean] true if persistence is enabled
  def enabled?(catalog)
    catalog.host_config? && Puppet.run_mode.name == :agent
  end
end
