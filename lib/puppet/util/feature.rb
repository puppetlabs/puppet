require 'puppet'

class Puppet::Util::Feature
  attr_reader :path

  # Create a new feature test.  You have to pass the feature name,
  # and it must be unique.  You can either provide a block that
  # will get executed immediately to determine if the feature
  # is present, or you can pass an option to determine it.
  # Currently, the only supported option is 'libs' (must be
  # passed as a symbol), which will make sure that each lib loads
  # successfully.
  def add(name, options = {})
    method = name.to_s + "?"
    @results.delete(name)

    if block_given?
      begin
        result = yield
      rescue StandardError,ScriptError => detail
        warn _("Failed to load feature test for %{name}: %{detail}") % { name: name, detail: detail }
        result = false
      end
      @results[name] = result
    end

    meta_def(method) do
      # we return a cached result if:
      #  * if a block is given (and we just evaluated it above)
      #  * if we already have a positive result
      #  * if we've tested this feature before and it failed, but we're
      #    configured to always cache
      if block_given?     ||
          @results[name]  ||
          (@results.has_key?(name) && (!Puppet[:always_retry_plugins]))
        @results[name]
      else
        @results[name] = test(name, options)
        @results[name]
      end
    end
  end

  # Create a new feature collection.
  def initialize(path)
    @path = path
    @results = {}
    @loader = Puppet::Util::Autoload.new(self, @path)
  end

  def load
    @loader.loadall
  end

  def method_missing(method, *args)
    return super unless method.to_s =~ /\?$/

    feature = method.to_s.sub(/\?$/, '')
    @loader.load(feature)

    respond_to?(method) && self.send(method)
  end

  # Actually test whether the feature is present.  We only want to test when
  # someone asks for the feature, so we don't unnecessarily load
  # files.
  def test(name, options)
    return true unless ary = options[:libs]
    ary = [ary] unless ary.is_a?(Array)

    ary.each do |lib|
      return false unless load_library(lib, name)
    end

    # We loaded all of the required libraries
    true
  end

  private

  def load_library(lib, name)
    raise ArgumentError, _("Libraries must be passed as strings not %{klass}") % { klass: lib.class } unless lib.is_a?(String)

    @rubygems ||= Puppet::Util::RubyGems::Source.new
    @rubygems.clear_paths

    begin
      require lib
    rescue ScriptError => detail
      Puppet.debug _("Failed to load library '%{lib}' for feature '%{name}': %{detail}") % { lib: lib, name: name, detail: detail }
      return false
    end
    true
  end
end
