# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
module Puppet::Pops
module Loader
class TaskInstantiator
  def self.create(loader, typed_name, source_refs)
    name = typed_name.name
    metadata = nil
    task_source = nil
    source_refs.each do |source_ref|
      if source_ref.end_with?('.json')
        metadata = source_ref
      elsif task_source.nil?
        task_source = source_ref
      else
        raise ArgumentError, _('Only one file can exists besides the .json file for task %{name} in directory %{directory}') %
          { name: name, directory: File.dirname(source_refs[0]) }
      end
    end

    if task_source.nil?
      raise ArgumentError, _('No source besides task metadata was found in directory %{directory} for task %{name}') %
        { name: name, directory: File.dirname(source_refs[0]) }
    end
    create_task(loader, name, task_source, metadata)
  end

  def self.create_task(loader, name, task_source, metadata)
    if metadata.nil?
      create_task_from_hash(name, task_source, EMPTY_HASH)
    else
      json_text = loader.get_contents(metadata)
      begin
        create_task_from_hash(name, task_source, Puppet::Util::Json.load(json_text) || EMPTY_HASH)
      rescue Puppet::Util::Json::ParseError => ex
        raise Puppet::ParseError.new(ex.message, metadata)
      rescue Types::TypeAssertionError => ex
        # Not strictly a parser error but from the users perspective, the file content didn't parse properly. The
        # ParserError also conveys file info (even though line is unknown)
        msg = _('Failed to load metadata for task %{name}: %{reason}') % { :name => name, :reason => ex.message }
        raise Puppet::ParseError.new(msg, metadata)
      end
    end
  end

  def self.create_task_from_hash(name, task_source, hash)
    arguments = {
      'name' => name,
      'executable' => task_source
    }
    hash.each_pair do |key, value|
      if 'parameters' == key || 'output' == key
        ps = {}
        value.each_pair do |k, v|
          pd = v.dup
          t = v['type']
          pd['type'] = t.nil? ? Types::TypeFactory.data : Types::TypeParser.singleton.parse(t)
          ps[k] = pd
        end
        value = ps
      end
      arguments[key] = value
    end

    Types::TypeFactory.task.from_hash(arguments)
  end
end
end
end
