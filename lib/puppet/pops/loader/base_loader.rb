module Puppet::Pops
module Loader
# BaseLoader
# ===
# An abstract implementation of Loader
#
# A derived class should implement `find(typed_name)` and set entries, and possible handle "miss caching".
#
# @api private
#
class BaseLoader < Loader

  # The parent loader
  attr_reader :parent

  # An internal name used for debugging and error message purposes
  attr_reader :loader_name

  def initialize(parent_loader, loader_name)
    @parent = parent_loader # the higher priority loader to consult
    @named_values = {}      # hash name => NamedEntry
    @last_result = nil      # the value of the last name (optimization)
    @loader_name = loader_name # the name of the loader (not the name-space it is a loader for)
  end

  # @api public
  #
  def load_typed(typed_name)
    # The check for "last queried name" is an optimization when a module searches. First it checks up its parent
    # chain, then itself, and then delegates to modules it depends on.
    # These modules are typically parented by the same
    # loader as the one initiating the search. It is inefficient to again try to search the same loader for
    # the same name.
    if @last_result.nil? || typed_name != @last_result.typed_name
      @last_result = internal_load(typed_name)
    else
      @last_result
    end
  end

  # @api public
  #
  def loaded_entry(typed_name, check_dependencies = false)
    if @named_values.has_key?(typed_name)
      @named_values[typed_name]
    elsif parent
      parent.loaded_entry(typed_name, check_dependencies)
    else
      nil
    end
  end

  # This method is final (subclasses should not override it)
  #
  # @api private
  #
  def get_entry(typed_name)
    @named_values[typed_name]
  end

  # @api private
  #
  def set_entry(typed_name, value, origin = nil)
    # It is never ok to redefine in the very same loader unless redefining a 'not found'
    if entry = @named_values[typed_name]
      fail_redefine(entry) unless entry.value.nil?
    end

    # Check if new entry shadows existing entry and fail
    # (unless special loader allows shadowing)
    if typed_name.type == :type && !allow_shadowing?
      entry = loaded_entry(typed_name)
      if entry
        fail_redefine(entry) unless entry.value.nil? #|| entry.value == value
      end
    end

    @last_result = Loader::NamedEntry.new(typed_name, value, origin)
    @named_values[typed_name] = @last_result
  end

  # @api private
  #
  def add_entry(type, name, value, origin)
    set_entry(TypedName.new(type, name), value, origin)
  end

  # Promotes an already created entry (typically from another loader) to this loader
  #
  # @api private
  #
  def promote_entry(named_entry)
    typed_name = named_entry.typed_name
    if entry = @named_values[typed_name] then fail_redefine(entry); end
    @named_values[typed_name] = named_entry
  end

  protected

  def allow_shadowing?
    false
  end

  private

  def fail_redefine(entry)
    origin_info = entry.origin ? "Originally set #{origin_label(entry.origin)}." : "Set at unknown location"
    raise ArgumentError, "Attempt to redefine entity '#{entry.typed_name}'. #{origin_info}"
  end

  # TODO: Should not really be here?? - TODO: A Label provider ? semantics for the URI?
  #
  def origin_label(origin)
    if origin && origin.is_a?(URI)
      format_uri(origin)
    elsif origin.respond_to?(:uri)
      format_uri(origin.uri)
    else
      origin
    end
  end

  def format_uri(uri)
    (uri.scheme == 'puppet' ? 'by ' : 'at ') + uri.to_s.sub(/^puppet:/,'')
  end

  # loads in priority order:
  # 1. already loaded here
  # 2. load from parent
  # 3. find it here
  # 4. give up
  #
  def internal_load(typed_name)
    # avoid calling get_entry, by looking it up
    te = @named_values[typed_name]
    te = parent.load_typed(typed_name) if te.nil? || te.value.nil?
    te = find(typed_name) if te.nil? || te.value.nil?
    te
  end

end
end
end
