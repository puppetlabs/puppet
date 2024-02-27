# frozen_string_literal: true

require_relative '../../puppet/util/logging'

class Puppet::Module
  class Plan
    class Error < Puppet::Error
      attr_accessor :kind, :details

      def initialize(message, kind, details = nil)
        super(message)
        @details = details || {}
        @kind = kind
      end

      def to_h
        {
          msg: message,
          kind: kind,
          details: details
        }
      end
    end

    class InvalidName < Error
      def initialize(name, msg)
        super(msg, 'puppet.plans/invalid-name')
      end
    end

    class InvalidFile < Error
      def initialize(msg)
        super(msg, 'puppet.plans/invalid-file')
      end
    end

    class InvalidPlan < Error
    end

    class InvalidMetadata < Error
    end

    class PlanNotFound < Error
      def initialize(plan_name, module_name)
        msg = _("Plan %{plan_name} not found in module %{module_name}.") %
              { plan_name: plan_name, module_name: module_name }
        super(msg, 'puppet.plans/plan-not-found', { 'name' => plan_name })
      end
    end

    ALLOWED_EXTENSIONS = %w[.pp .yaml]
    RESERVED_WORDS = %w[and application attr case class consumes default else
                        elsif environment false function if import in inherits node or private
                        produces site true type undef unless]
    RESERVED_DATA_TYPES = %w[any array boolean catalogentry class collection
                             callable data default enum float hash integer numeric optional pattern
                             resource runtime scalar string struct tuple type undef variant]

    def self.is_plan_name?(name)
      return true if name =~ /^[a-z][a-z0-9_]*$/

      return false
    end

    # Determine whether a plan file has a legal name and extension
    def self.is_plans_filename?(path)
      name = File.basename(path, '.*')
      ext = File.extname(path)
      return [false, _("Plan names must start with a lowercase letter and be composed of only lowercase letters, numbers, and underscores")] unless is_plan_name?(name)
      unless ALLOWED_EXTENSIONS.include? ext
        return [false, _("Plan name cannot have extension %{ext}, must be .pp or .yaml") % { ext: ext }]
      end
      if RESERVED_WORDS.include?(name)
        return [false, _("Plan name cannot be a reserved word, but was '%{name}'") % { name: name }]
      end
      if RESERVED_DATA_TYPES.include?(name)
        return [false, _("Plan name cannot be a Puppet data type, but was '%{name}'") % { name: name }]
      end

      return [true]
    end

    # Executables list should contain the full path of all possible implementation files
    def self.find_implementations(name, plan_files)
      basename = name.split('::')[1] || 'init'

      # If implementations isn't defined, then we use executables matching the
      # plan name, and only one may exist.
      implementations = plan_files.select { |impl| File.basename(impl, '.*') == basename }

      # Select .pp before .yaml, since .pp comes before .yaml alphabetically.
      chosen = implementations.sort.first

      [{ "name" => File.basename(chosen), "path" => chosen }]
    end
    private_class_method :find_implementations

    def self.find_files(name, plan_files)
      find_implementations(name, plan_files)
    end

    def self.plans_in_module(pup_module)
      # Search e.g. 'modules/<pup_module>/plans' for all plans
      plan_files = Dir.glob(File.join(pup_module.plans_directory, '*'))
                      .keep_if { |f| valid, _ = is_plans_filename?(f); valid }

      plans = plan_files.group_by { |f| plan_name_from_path(f) }

      plans.map do |plan, plan_filenames|
        new_with_files(pup_module, plan, plan_filenames)
      end
    end

    attr_reader :name, :module, :metadata_file

    # file paths must be relative to the modules plan directory
    def initialize(pup_module, plan_name, plan_files)
      valid, reason = Puppet::Module::Plan.is_plans_filename?(plan_files.first)
      unless valid
        raise InvalidName.new(plan_name, reason)
      end

      name = plan_name == "init" ? pup_module.name : "#{pup_module.name}::#{plan_name}"

      @module = pup_module
      @name = name
      @metadata_file = metadata_file
      @plan_files = plan_files || []
    end

    def metadata
      # Nothing to go here unless plans eventually support metadata.
      @metadata ||= {}
    end

    def files
      @files ||= self.class.find_files(@name, @plan_files)
    end

    def validate
      files
      true
    end

    def ==(other)
      self.name == other.name &&
        self.module == other.module
    end

    def environment_name
      @module.environment.respond_to?(:name) ? @module.environment.name : 'production'
    end
    private :environment_name

    def self.new_with_files(pup_module, name, plan_files)
      Puppet::Module::Plan.new(pup_module, name, plan_files)
    end
    private_class_method :new_with_files

    # Abstracted here so we can add support for subdirectories later
    def self.plan_name_from_path(path)
      return File.basename(path, '.*')
    end
    private_class_method :plan_name_from_path
  end
end
