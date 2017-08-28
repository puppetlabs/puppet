require 'json'

module Puppet::Pops
module Types
  # Ruby implementation of the Task Pcore type. It is the super type of a custom task that either has parameters
  # or explicitly declared that it has zero parameters (by providing an empty parameters clause).
  class Task
    include PuppetObject

    # Pattern used for task parameter names
    PARAMETER_NAME_PATTERN = PPatternType.new([PRegexpType.new(/\A[a-z][a-z0-9_]*\z/)])

    # Register the Task type with the Pcore loader and implementation registry
    def self.register_ptype(loader, ir)
      @type = Pcore::create_object_type(loader, ir, self, 'Task', nil, {
        'supports_noop' => {
          'type' => PBooleanType::DEFAULT,
          'value' => false,
          'kind' => 'constant'
        },
        'input_method' => {
          'type' => PStringType::DEFAULT,
          'value' => 'stdin',
          'kind' => 'constant'
        },
        'executable' => {
          'type' => PStringType::DEFAULT,
          'kind' => 'constant',
          'value' => ''
        },
        'task_json' => {
          'type' => PStringType::DEFAULT,
          'kind' => 'derived'
        },
      })
    end

    def self._pcore_type
      @type
    end

    # Calculates the full path of the executable file. It is required that the type was loaded
    # using a file based loader
    # @return [String] The full path to the executable.
    def executable_path
      loader = _pcore_type.loader
      unless loader.is_a?(Loader::ModuleLoaders::FileBased)
        raise Puppet::Error,
          _('Absolute path of executable %{file} for task %{task} cannot be determined. This type was not loaded by a file based loader') %
          { :filename => executable, :task => _pcore_type.name }
      end
      File.join(loader.path, 'tasks', executable)
    end

    # Returns the parameters of this instance represented as a JSON string
    # @return [String] the JSON string representation of all parameter values
    def task_json
      # Convert this instance into Data and strip off the __pcore_type__ key. It's not
      # needed when executing the task
      rich_json = Serialization::ToDataConverter.convert(self, :rich_data => true)
      rich_json.delete('__pcore_type__')
      rich_json.to_json
    end
  end

  # Ruby implementation of the GenericTask. It is a specialization of the Task Pcore type used as the super type
  # of custom task that lacks a 'parameters' definition (or lacks metadata altogether). This task accepts any
  # parameters and keeps them in an 'args' hash.
  class GenericTask < Task
    # Register the GenericTask type with the Pcore loader and implementation registry
    def self.register_ptype(loader, ir)
      @type = Pcore::create_object_type(loader, ir, self, 'GenericTask', 'Task', {
        'args' => PHashType.new(PARAMETER_NAME_PATTERN, PTypeReferenceType.new('Data'))
      })
    end

    def self._pcore_type
      @type
    end

    attr_reader :args

    def _pcore_init_hash
      { 'args' => args }
    end

    def initialize(args)
      @args = args
    end

    def task_json
      @args.to_json
    end
  end
end
end
