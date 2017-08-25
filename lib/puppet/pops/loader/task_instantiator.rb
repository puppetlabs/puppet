# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
module Puppet::Pops
module Loader
class TaskInstantiator
  def self.create(loader, typed_name, source_refs)
    ensure_initialized
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
    create_task_type(loader, typed_name, task_source, metadata)
  end

  def self.create_task_type(loader, typed_name, task_source, metadata)
    if metadata.nil?
      create_task_type_from_hash(loader, typed_name, task_source, EMPTY_HASH)
    else
      json_text = loader.get_contents(metadata)
      begin
        hash = JSON.parse(json_text) || EMPTY_HASH
        Types::TypeAsserter.assert_instance_of(nil, @type_hash_t, hash) { _('The metadata for task %{name}') % { name: typed_name.name } }
        create_task_type_from_hash(loader, typed_name, task_source, hash)
      rescue JSON::ParserError => ex
        raise Puppet::ParseError.new(ex.message, metadata)
      rescue Types::TypeAssertionError => ex
        # Not strictly a parser error but from the users perspective, the file content didn't parse properly. The
        # ParserError also conveys file info (even though line is unknown)
        raise Puppet::ParseError.new(ex.message, metadata)
      end
    end
  end

  def self.ensure_initialized
    return if @initialized
    @initialized = true

    tf = Types::TypeFactory
    params_t = tf.hash_kv(
      Types::Task::PARAMETER_NAME_PATTERN,
      tf.struct(
        tf.optional('description') => tf.string,
        tf.optional('type') => Types::PStringType::NON_EMPTY
      )
    )

    @type_hash_t = tf.struct(
      tf.optional('description') => tf.string,
      tf.optional('puppet_task_version') => tf.string,
      tf.optional('supports_noop') => tf.boolean,
      tf.optional('input_method') => tf.enum('stdin', 'environment'),
      'parameters' => params_t,
      tf.optional('output') => params_t
    )
  end

  def self.create_task_type_from_hash(loader, typed_name, task_source, hash)
    attributes = {}
    constants = {}
    parameters_entry_found = false
    hash.each_pair do |key, value|
      if 'parameters' == key
        parameters_entry_found = true
        value.each_pair do |param_name, param_decl|
          attributes[param_name] = create_attribute(loader, param_decl)
        end
      else
        constants[key] = value
      end
    end

    if parameters_entry_found
      parent_type = 'Task'
    else
      # No entry means any parameters
      attributes = EMPTY_HASH
      parent_type = 'GenericTask'
    end

    constants['executable'] = Pathname(task_source).relative_path_from(Pathname(loader.path) + 'tasks').to_s

    Types::TypeFactory.object(
      {
        'name' => Types::TypeFormatter.singleton.capitalize_segments(typed_name.name),
        'parent' => Types::TypeParser.singleton.parse(parent_type, loader),
        'attributes' => attributes,
        'constants' => constants
      }, loader)
  end

  def self.create_attribute(loader, param_decl)
    result = {}
    type = Types::TypeParser.singleton.parse(param_decl['type'] || 'Data', loader)

    # Treat OptionalType as optional attribute entry, i.e. provide a default of undef
    result['value'] = nil if type.is_a?(Types::POptionalType)

    result['type'] = type
    result
  end
end
end
end
