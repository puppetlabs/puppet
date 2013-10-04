# A Backend implementation capable of reading YAML syntax
class Puppet::Pops::Binder::Hiera2::YamlBackend < Puppetx::Puppet::Hiera2Backend
  def read_data(module_dir, source)
    begin
      source_file = File.join(module_dir, "#{source}.yaml")
      # if file is present but empty or has only "---", YAML.load_file returns false,
      # in which case fall back to returning an empty hash
      YAML.load_file(source_file) || {}
    rescue TypeError => e
      # SafeYaml chokes when trying to load using utf-8 and the file is empty
      raise e if File.size?(source_file)
      {}
    rescue Errno::ENOTDIR
      # This is OK, the file doesn't need to be present. Return an empty hash
      {}
    rescue Errno::ENOENT
      # This is OK, the file doesn't need to be present. Return an empty hash
      {}
    end
  end
end
