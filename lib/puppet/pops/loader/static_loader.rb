  # Static Loader contains constants, basic data types and other types required for the system
  # to boot.
  #
class Puppet::Pops::Loader::StaticLoader < Puppet::Pops::Loader::Loader

  attr_reader :loaded
  def initialize
    @loaded = {}
    create_logging_functions()
  end

  def load_typed(typed_name)
    load_constant(typed_name)
  end

  def get_entry(typed_name)
    load_constant(typed_name)
  end

  def find(name)
    # There is nothing to search for, everything this loader knows about is already available
    nil
  end

  def parent
    nil # at top of the hierarchy
  end

  def to_s()
    "(StaticLoader)"
  end
  private

  def load_constant(typed_name)
    @loaded[typed_name]
  end

  private

  # Creates a function for each of the specified log levels
  #
  def create_logging_functions()
    Puppet::Util::Log.levels.each do |level|

      fc = Puppet::Functions.create_function(level) do
        # create empty dispatcher to stop it from complaining about missing method since
        # an override of :call is made instead of using dispatch.
        dispatch(:log) { }

        # Logs per the specified level, outputs formatted information for arrays, hashes etc.
        # Overrides the implementation in Function that uses dispatching. This is not needed here
        # since it accepts 0-n Optional[Object]
        #
        define_method(:call) do |scope, *vals|
          # NOTE: 3x, does this: vals.join(" ")
          # New implementation uses the evaluator to get proper formatting per type
          # TODO: uses a fake scope (nil) - fix when :scopes are available via settings
          mapped = vals.map {|v| Puppet::Pops::Evaluator::EvaluatorImpl.new.string(v, nil) }
          Puppet.send(level, mapped.join(" "))
        end
      end

      typed_name = Puppet::Pops::Loader::Loader::TypedName.new(:function, level)
      # TODO:closure scope is fake (an empty hash) - waiting for new global scope to be available via lookup of :scopes
      func = fc.new({},self)
      @loaded[ typed_name ] = Puppet::Pops::Loader::Loader::NamedEntry.new(typed_name, func, __FILE__)
    end
  end
end
