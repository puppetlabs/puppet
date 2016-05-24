require 'yaml'
require 'puppet/util/yaml'

# A persistence store implementation for storing information between
# transaction runs for the purposes of information inference (such
# as calculating corrective_change).
class Puppet::Transaction::Persistence
  def initialize
    @filename = Puppet[:transactionstorefile]

    @data = {"resources" => {}}
  end

  # Obtain the full raw data from the persistence store.
  # @return [Hash] hash of data stored in persistence store
  def data
    @data
  end

  # Return just the resource specific data from the persistence store.
  # @return [Hash] hash of resources data in persistence store
  def resources
    @data["resources"]
  end

  # Set the resource specific data in the persistence store.
  # @param value [Hash] new hash to store for resources in persistence store.
  def resources=(value)
    @data["resources"] = value
  end

  # Retrieve the system value using the resource and parameter name
  # @param [String] resource_name name of resource
  # @param [String] param_name name of the parameter
  # @return [Object,nil] the system_value
  def get_system_value(resource_name, param_name)
    if !@data["resources"][resource_name].nil? &&
       !@data["resources"][resource_name]["parameters"].nil? &&
       !@data["resources"][resource_name]["parameters"][param_name].nil?
      @data["resources"][resource_name]["parameters"][param_name]["system_value"]
    else
      nil
    end
  end

  # Load data from the persistence store on disk.
  def load
    unless Puppet::FileSystem.exist?(@filename)
      return
    end
    unless File.file?(@filename)
      Puppet.warning("Persistence file #{@filename} is not a file, ignoring")
      return
    end

    result = nil
    Puppet::Util.benchmark(:debug, "Loaded transaction") do
      begin
        result = Puppet::Util::Yaml.load_file(@filename)
      rescue Puppet::Util::Yaml::YamlLoadError => detail
        Puppet.err "Persistence file #{@filename} is corrupt (#{detail}); replacing"

        begin
          File.rename(@filename, @filename + ".bad")
        rescue
          raise Puppet::Error, "Could not rename corrupt #{@filename}; remove manually", detail.backtrace
        end
      end
    end

    unless result.is_a?(Hash)
      Puppet.err "State got corrupted"
      return
    end

    @data = result
  end

  # Save data from internal class to persistence store on disk.
  def save
    Puppet::Util::Yaml.dump(@data, @filename)
  end
end
