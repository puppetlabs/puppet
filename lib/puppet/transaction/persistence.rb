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

  # Load data from the persistence store on disk.
  def load
    filename = Puppet[:transactionstorefile]
    unless Puppet::FileSystem.exist?(filename)
      return
    end
    unless File.file?(filename)
      Puppet.warning("Persistence file #{filename} is not a file, ignoring")
      return
    end

    result = nil
    Puppet::Util.benchmark(:debug, "Loaded transaction store file") do
      begin
        result = Puppet::Util::Yaml.load_file(filename)
      rescue Puppet::Util::Yaml::YamlLoadError => detail
        Puppet.err "Transaction store file #{filename} is corrupt (#{detail}); replacing"

        begin
          File.rename(filename, filename + ".bad")
        rescue
          raise Puppet::Error, "Could not rename corrupt transaction store file #{filename}; remove manually", detail.backtrace
        end
      end
    end

    unless result.is_a?(Hash)
      Puppet.err "Transaction state file #{filename} is valid YAML but not returning a hash. Check the file for corruption, or remove it before continuing."
      return
    end

    @old_data = result
  end

  # Save data from internal class to persistence store on disk.
  def save
    Puppet::Util::Yaml.dump(@new_data, Puppet[:transactionstorefile])
  end
end
