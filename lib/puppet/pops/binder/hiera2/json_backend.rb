require 'json'

# A Backend implementation capable of reading JSON syntax
class Puppet::Pops::Binder::Hiera2::JsonBackend < Puppetx::Puppet::Hiera2Backend
  def read_data(module_dir, source)
    begin
      source_file = File.join(module_dir, "#{source}.json")
      JSON.parse(File.read(source_file))
    rescue Errno::ENOTDIR
      # This is OK, the file doesn't need to be present. Return an empty hash
      {}
    rescue Errno::ENOENT
      # This is OK, the file doesn't need to be present. Return an empty hash
      {}
    end
  end
end

