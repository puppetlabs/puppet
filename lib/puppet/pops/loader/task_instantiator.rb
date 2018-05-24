# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
module Puppet::Pops
module Loader
class TaskInstantiator
  def self.load_metadata(loader, metadata)
    if metadata.nil?
      EMPTY_HASH
    else
      json_text = loader.get_contents(metadata)
      begin
        Puppet::Util::Json.load(json_text).freeze || EMPTY_HASH
      rescue Puppet::Util::Json::ParseError => ex
        raise Puppet::ParseError.new(ex.message, metadata)
      end
    end
  end

  def self.validate_implementations(typed_name, directory, metadata, executables)
    name = typed_name.name
    basename = typed_name.name_parts[1] || 'init'
    # If 'implementations' is defined, it needs to mention at least one
    # implementation, and everything it mentions must exist.
    if metadata.key?('implementations')
      if metadata['implementations'].is_a?(Array)
        metadata['implementations'].map do |impl|
          path = executables.find { |real_impl| File.basename(real_impl) == impl['name'] }
          if path
            { "name" => impl['name'], "requirements" => impl.fetch('requirements', []), "path" => path }
          else
            raise ArgumentError, _("Task metadata for task %{name} specifies missing implementation %{implementation}") %
              { name: name, implementation: impl['name'] }
          end
        end
      else
        # If 'implementations' is the wrong type, we just pass it through and
        # let the task type definition reject it.
        metadata['implementations']
      end
    # If implementations isn't defined, then we use executables matching the
    # task name, and only one may exist.
    else
      implementations = executables.select { |impl| File.basename(impl, '.*') == basename }
      if implementations.empty?
        raise ArgumentError, _('No source besides task metadata was found in directory %{directory} for task %{name}') %
          { name: name, directory: directory }
      elsif implementations.length > 1
        raise ArgumentError, _("Multiple executables were found in directory %{directory} for task %{name}; define 'implementations' in metadata to differentiate between them") %
          { name: name, directory: implementations[0] }
      end

      [{ "name" => File.basename(implementations.first), "path" => implementations.first, "requirements" => [] }]
    end
  end

  def self.create(loader, typed_name, source_refs)
    name = typed_name.name
    basename = typed_name.name_parts[1] || 'init'
    dirname = File.dirname(source_refs[0])
    metadata_files, executables = source_refs.partition { |source_ref| source_ref.end_with?('.json') }
    metadata_file = metadata_files.find { |source_ref| File.basename(source_ref, '.json') == basename }

    metadata = load_metadata(loader, metadata_file)

    implementation_metadata = validate_implementations(typed_name, dirname, metadata, executables)

    arguments = {
      'name' => name,
      'implementations' => implementation_metadata
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

      Types::TypeFactory.task.from_hash(arguments)
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
