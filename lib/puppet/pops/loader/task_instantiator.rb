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

    metadata = Puppet::Module::Task.read_metadata(metadata_file) || {}

    files = Puppet::Module::Task.find_files(name, dirname, metadata, executables)

    task = { 'name' => name, 'metadata' => metadata, 'files' => files }

    begin
      task['parameters'] = convert_types(metadata['parameters'])

      Types::TypeFactory.task.from_hash(task)
    rescue Types::TypeAssertionError => ex
      # Not strictly a parser error but from the users perspective, the file content didn't parse properly. The
      # ParserError also conveys file info (even though line is unknown)
      msg = _('Failed to load metadata for task %{name}: %{reason}') % { name: name, reason: ex.message }
      raise Puppet::ParseError.new(msg, metadata_file)
    end
  end

  def self.convert_types(args)
    args.each_with_object({}) do |(k, v), hsh|
      hsh[k] = v['type'].nil? ? Types::TypeFactory.data : Types::TypeParser.singleton.parse(v['type'])
    end if args
  end
  private_class_method :convert_types
end
end
end
