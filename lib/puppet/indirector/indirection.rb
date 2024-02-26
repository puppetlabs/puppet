# frozen_string_literal: true

require_relative '../../puppet/util/docs'
require_relative '../../puppet/util/profiler'
require_relative '../../puppet/indirector/envelope'
require_relative '../../puppet/indirector/request'
require_relative '../../puppet/thread_local'

# The class that connects functional classes with their different collection
# back-ends.  Each indirection has a set of associated terminus classes,
# each of which is a subclass of Puppet::Indirector::Terminus.
class Puppet::Indirector::Indirection
  include Puppet::Util::Docs

  attr_accessor :name, :model
  attr_reader :termini

  @@indirections = []

  # Find an indirection by name.  This is provided so that Terminus classes
  # can specifically hook up with the indirections they are associated with.
  def self.instance(name)
    @@indirections.find { |i| i.name == name }
  end

  # Return a list of all known indirections.  Used to generate the
  # reference.
  def self.instances
    @@indirections.collect { |i| i.name }
  end

  # Find an indirected model by name.  This is provided so that Terminus classes
  # can specifically hook up with the indirections they are associated with.
  def self.model(name)
    match = @@indirections.find { |i| i.name == name }
    return nil unless match

    match.model
  end

  # Create and return our cache terminus.
  def cache
    raise Puppet::DevError, _("Tried to cache when no cache class was set") unless cache_class

    terminus(cache_class)
  end

  # Should we use a cache?
  def cache?
    cache_class ? true : false
  end

  def cache_class
    @cache_class.value
  end

  # Define a terminus class to be used for caching.
  def cache_class=(class_name)
    validate_terminus_class(class_name) if class_name
    @cache_class.value = class_name
  end

  # This is only used for testing.
  def delete
    @@indirections.delete(self) if @@indirections.include?(self)
  end

  # Set the time-to-live for instances created through this indirection.
  def ttl=(value)
    # TRANSLATORS "TTL" stands for "time to live" and refers to a duration of time
    raise ArgumentError, _("Indirection TTL must be an integer") unless value.is_a?(Integer)

    @ttl = value
  end

  # Default to the runinterval for the ttl.
  def ttl
    @ttl ||= Puppet[:runinterval]
  end

  # Calculate the expiration date for a returned instance.
  def expiration
    Time.now + ttl
  end

  # Generate the full doc string.
  def doc
    text = ''.dup

    text << scrub(@doc) << "\n\n" if @doc

    text << "* **Indirected Class**: `#{@indirected_class}`\n";
    if terminus_setting
      text << "* **Terminus Setting**: #{terminus_setting}\n"
    end

    text
  end

  def initialize(model, name, doc: nil, indirected_class: nil, cache_class: nil, terminus_class: nil, terminus_setting: nil, extend: nil)
    @model = model
    @name = name
    @termini = {}

    @doc = doc

    raise(ArgumentError, _("Indirection %{name} is already defined") % { name: @name }) if @@indirections.find { |i| i.name == @name }

    @@indirections << self

    @indirected_class = indirected_class
    self.extend(extend) if extend

    # Setting these depend on the indirection already being installed so they have to be at the end
    set_global_setting(:cache_class, cache_class)
    set_global_setting(:terminus_class, terminus_class)
    set_global_setting(:terminus_setting, terminus_setting)
  end

  # Use this to set indirector settings globally across threads.
  def set_global_setting(setting, value)
    case setting
    when :cache_class
      validate_terminus_class(value) unless value.nil?
      @cache_class = Puppet::ThreadLocal.new(value)
    when :terminus_class
      validate_terminus_class(value) unless value.nil?
      @terminus_class = Puppet::ThreadLocal.new(value)
    when :terminus_setting
      @terminus_setting = Puppet::ThreadLocal.new(value)
    else
      raise(ArgumentError, _("The setting %{setting} is not a valid indirection setting.") % { setting: setting })
    end
  end

  # Set up our request object.
  def request(*args)
    Puppet::Indirector::Request.new(self.name, *args)
  end

  # Return the singleton terminus for this indirection.
  def terminus(terminus_name = nil)
    # Get the name of the terminus.
    raise Puppet::DevError, _("No terminus specified for %{name}; cannot redirect") % { name: self.name } unless terminus_name ||= terminus_class

    termini[terminus_name] ||= make_terminus(terminus_name)
  end

  # These can be used to select the terminus class.
  def terminus_setting
    @terminus_setting.value
  end

  def terminus_setting=(setting)
    @terminus_setting.value = setting
  end

  # Determine the terminus class.
  def terminus_class
    unless @terminus_class.value
      setting = self.terminus_setting
      if setting
        self.terminus_class = Puppet.settings[setting]
      else
        raise Puppet::DevError, _("No terminus class nor terminus setting was provided for indirection %{name}") % { name: self.name }
      end
    end
    @terminus_class.value
  end

  def reset_terminus_class
    @terminus_class.value = nil
  end

  # Specify the terminus class to use.
  def terminus_class=(klass)
    validate_terminus_class(klass)
    @terminus_class.value = klass
  end

  # This is used by terminus_class= and cache=.
  def validate_terminus_class(terminus_class)
    unless terminus_class and terminus_class.to_s != ""
      raise ArgumentError, _("Invalid terminus name %{terminus_class}") % { terminus_class: terminus_class.inspect }
    end

    unless Puppet::Indirector::Terminus.terminus_class(self.name, terminus_class)
      raise ArgumentError, _("Could not find terminus %{terminus_class} for indirection %{name}") %
                           { terminus_class: terminus_class, name: self.name }
    end
  end

  # Expire a cached object, if one is cached.  Note that we don't actually
  # remove it, we expire it and write it back out to disk.  This way people
  # can still use the expired object if they want.
  def expire(key, options = {})
    request = request(:expire, key, nil, options)

    return nil unless cache? && !request.ignore_cache_save?

    instance = cache.find(request(:find, key, nil, options))
    return nil unless instance

    Puppet.info _("Expiring the %{cache} cache of %{instance}") % { cache: self.name, instance: instance.name }

    # Set an expiration date in the past
    instance.expiration = Time.now - 60

    cache.save(request(:save, nil, instance, options))
  end

  def allow_remote_requests?
    terminus.allow_remote_requests?
  end

  # Search for an instance in the appropriate terminus, caching the
  # results if caching is configured..
  def find(key, options = {})
    request = request(:find, key, nil, options)
    terminus = prepare(request)

    result = find_in_cache(request)
    if !result.nil?
      result
    elsif request.ignore_terminus?
      nil
    else
      # Otherwise, return the result from the terminus, caching if
      # appropriate.
      result = terminus.find(request)
      unless result.nil?
        result.expiration ||= self.expiration if result.respond_to?(:expiration)
        if cache? && !request.ignore_cache_save?
          Puppet.info _("Caching %{indirection} for %{request}") % { indirection: self.name, request: request.key }
          begin
            cache.save request(:save, key, result, options)
          rescue => detail
            Puppet.log_exception(detail)
            raise detail
          end
        end

        filtered = result
        if terminus.respond_to?(:filter)
          Puppet::Util::Profiler.profile(_("Filtered result for %{indirection} %{request}") % { indirection: self.name, request: request.key }, [:indirector, :filter, self.name, request.key]) do
            begin
              filtered = terminus.filter(result)
            rescue Puppet::Error => detail
              Puppet.log_exception(detail)
              raise detail
            end
          end
        end
        filtered
      end
    end
  end

  # Search for an instance in the appropriate terminus, and return a
  # boolean indicating whether the instance was found.
  def head(key, options = {})
    request = request(:head, key, nil, options)
    terminus = prepare(request)

    # Look in the cache first, then in the terminus.  Force the result
    # to be a boolean.
    !!(find_in_cache(request) || terminus.head(request))
  end

  def find_in_cache(request)
    # See if our instance is in the cache and up to date.
    cached = cache.find(request) if cache? && !request.ignore_cache?
    return nil unless cached

    if cached.expired?
      Puppet.info _("Not using expired %{indirection} for %{request} from cache; expired at %{expiration}") % { indirection: self.name, request: request.key, expiration: cached.expiration }
      return nil
    end

    Puppet.debug { "Using cached #{self.name} for #{request.key}" }
    cached
  rescue => detail
    Puppet.log_exception(detail, _("Cached %{indirection} for %{request} failed: %{detail}") % { indirection: self.name, request: request.key, detail: detail })
    nil
  end

  # Remove something via the terminus.
  def destroy(key, options = {})
    request = request(:destroy, key, nil, options)
    terminus = prepare(request)

    result = terminus.destroy(request)

    if cache? and cache.find(request(:find, key, nil, options))
      # Reuse the existing request, since it's equivalent.
      cache.destroy(request)
    end

    result
  end

  # Search for more than one instance.  Should always return an array.
  def search(key, options = {})
    request = request(:search, key, nil, options)
    terminus = prepare(request)

    result = terminus.search(request)
    if result
      raise Puppet::DevError, _("Search results from terminus %{terminus_name} are not an array") % { terminus_name: terminus.name } unless result.is_a?(Array)

      result.each do |instance|
        next unless instance.respond_to? :expiration

        instance.expiration ||= self.expiration
      end
      return result
    end
  end

  # Save the instance in the appropriate terminus.  This method is
  # normally an instance method on the indirected class.
  def save(instance, key = nil, options = {})
    request = request(:save, key, instance, options)
    terminus = prepare(request)

    result = terminus.save(request) unless request.ignore_terminus?

    # If caching is enabled, save our document there
    cache.save(request) if cache? && !request.ignore_cache_save?

    result
  end

  private

  # Check authorization if there's a hook available; fail if there is one
  # and it returns false.
  def check_authorization(request, terminus)
    # At this point, we're assuming authorization makes no sense without
    # client information.
    return unless request.node

    # This is only to authorize via a terminus-specific authorization hook.
    return unless terminus.respond_to?(:authorized?)

    unless terminus.authorized?(request)
      msg = if request.options.empty?
              _("Not authorized to call %{method} on %{description}") %
                { method: request.method, description: request.description }
            else
              _("Not authorized to call %{method} on %{description} with %{option}") %
                { method: request.method, description: request.description, option: request.options.inspect }
            end
      raise ArgumentError, msg
    end
  end

  # Pick the appropriate terminus, check the request's authorization, and return it.
  # @param [Puppet::Indirector::Request] request instance
  # @return [Puppet::Indirector::Terminus] terminus instance (usually a subclass
  #   of Puppet::Indirector::Terminus) for this request
  def prepare(request)
    # Pick our terminus.
    terminus_name = terminus_class

    dest_terminus = terminus(terminus_name)
    check_authorization(request, dest_terminus)
    dest_terminus.validate(request)

    dest_terminus
  end

  # Create a new terminus instance.
  def make_terminus(terminus_class)
    # Load our terminus class.
    klass = Puppet::Indirector::Terminus.terminus_class(self.name, terminus_class)
    unless klass
      raise ArgumentError, _("Could not find terminus %{terminus_class} for indirection %{indirection}") % { terminus_class: terminus_class, indirection: self.name }
    end

    klass.new
  end
end
