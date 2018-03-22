# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
module Puppet::Pops
module Loader
class TaskInstantiator
  def self.create(loader, typed_name, source_refs)
    name = typed_name.name
    metadata = source_refs.find {|source_ref| source_ref.end_with?('.json')}
    implementations = source_refs - [metadata]

    if implementations.empty?
      raise ArgumentError, _('No source besides task metadata was found in directory %{directory} for task %{name}') %
        { name: name, directory: File.dirname(source_refs[0]) }
    end
    create_task(loader, name, implementations, metadata)
  end

  def self.create_task(loader, name, implementations, metadata)
    if metadata.nil?
      create_task_from_hash(name, implementations, EMPTY_HASH)
    else
      json_text = loader.get_contents(metadata)
      begin
        create_task_from_hash(name, implementations, Puppet::Util::Json.load(json_text) || EMPTY_HASH)
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

  def self.create_task_from_hash(name, implementations, hash)
    # If 'implementations' is defined, it needs to mention at least one
    # implementation, and everything it mentions must exist.
    if hash.key?('implementations')
      if hash['implementations'].is_a?(Array)
        implementation_metadata = hash['implementations'].map do |impl|
          path = implementations.find {|real_impl| File.basename(real_impl) == impl['name']}
          if path
            {"name" => impl['name'], "requirements" => impl.fetch('requirements', []), "path" => path}
          else
            raise ArgumentError, _("Task metadata for task %{name} specifies missing implementation %{implementation}") %
              { name: name, implementation: impl['name'] }
          end
        end
      else
        # If 'implementations' is the wrong type, we just pass it through and
        # let the task type definition reject it.
        implementation_metadata = hash['implementations']
      end
    # If implementations isn't defined, then only one executable may exist.
    else
      if implementations.length > 1
        # XXX This message sucks
        raise ArgumentError, _("Multiple executables were found in directory %{directory} for task %{name}, without differentiating metadata") %
          { name: name, directory: File.dirname(implementations[0]) }
      end

      implementation_metadata = [{"name" => File.basename(implementations.first), "path" => implementations.first, "requirements" => []}]
    end

    arguments = {
      'name' => name,
      'implementations' => implementation_metadata
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
      arguments[key] = value unless arguments.key?(key)
    end

    Types::TypeFactory.task.from_hash(arguments)
  end
end
end
end
