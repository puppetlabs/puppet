# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
require 'puppet/module/task'
module Puppet::Pops
module Loader
class TaskInstantiator
  def self.create(loader, typed_name, source_refs)
    name = typed_name.name
    basename = typed_name.name_parts[1] || 'init'
    dirname = File.dirname(source_refs[0])
    metadata_files, executables = source_refs.partition { |source_ref| source_ref.end_with?('.json') }
    metadata_file = metadata_files.find { |source_ref| File.basename(source_ref, '.json') == basename }

    metadata = Puppet::Module::Task.read_metadata(metadata_file)

    implementations = Puppet::Module::Task.find_implementations(name, dirname, metadata, executables)
    files = Puppet::Module::Task.find_files(metadata)

    arguments = {
      'name' => name,
      'implementations' => implementations,
      'files' => files
    }

    begin
      metadata.each_pair do |key, value|
        if %w[parameters output].include?(key)
          ps = {}
          value.each_pair do |k, v|
            pd = v.dup
            t = v['type']
            pd['type'] = t.nil? ? Types::TypeFactory.data : Types::TypeParser.singleton.parse(t)
            ps[k] = pd
          end
          value = ps
        end
        arguments[key] = value unless arguments.key?(key)
      end

      arguments
    rescue Types::TypeAssertionError => ex
      # Not strictly a parser error but from the users perspective, the file content didn't parse properly. The
      # ParserError also conveys file info (even though line is unknown)
      msg = _('Failed to load metadata for task %{name}: %{reason}') % { name: name, reason: ex.message }
      raise Puppet::ParseError.new(msg, metadata_file)
    end
  end
end
end
end
