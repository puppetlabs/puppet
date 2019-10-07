require 'puppet'
require 'puppet/util/warnings'

class Puppet::Util::Feature
  include Puppet::Util::Warnings

  attr_reader :path

  # Create a new feature test. You have to pass the feature name, and it must be
  # unique. You can pass a block to determine if the feature is present:
  #
  #     Puppet.features.add(:myfeature) do
  #       # return true or false if feature is available
  #       # return nil if feature may become available later
  #     end
  #
  # The block should return true if the feature is available, false if it is
  # not, or nil if the state is unknown. True and false values will be cached. A
  # nil value will not be cached, and should be used if the feature may become
  # true in the future.
  #
  # Features are often used to detect if a ruby library is installed. To support
  # that common case, you can pass one or more ruby libraries, and the feature
  # will be true if all of the libraries load successfully:
  #
  #     Puppet.features.add(:myfeature, libs: 'mylib')
  #     Puppet.features.add(:myfeature, libs: ['mylib', 'myotherlib'])
  #
  # If the ruby library is not installed, then the failure is not cached, as
  # it's assumed puppet may install the gem during catalog application.
  #
  # If a feature is defined using `:libs` and a block, then the block is
  # used and the `:libs` are ignored.
  #
  # Puppet evaluates the feature test when the `Puppet.features.myfeature?`
  # method is called. If the feature test was defined using a block and the
  # block returns nil, then the feature test will be re-evaluated the next time
  # `Puppet.features.myfeature?` is called.
  #
  # @param [Symbol] name The unique feature name
  # @param [Hash<Symbol,Array<String>>] options The libraries to load
  def add(name, options = {}, &block)
    method = name.to_s + "?"
    @results.delete(name)

    meta_def(method) do
      # we return a cached result if:
      #  * if we've tested this feature before
      #  AND
      #    * the result was true/false
      #    OR
      #    * we're configured to never retry
      if @results.has_key?(name) &&
         (!@results[name].nil? || !Puppet[:always_retry_plugins])
        !!@results[name]
      else
        @results[name] = test(name, options, &block)
        !!@results[name]
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
    @loader.loadall(Puppet.lookup(:current_environment))
  end

  def method_missing(method, *args)
    return super unless method.to_s =~ /\?$/

    feature = method.to_s.sub(/\?$/, '')
    @loader.load(feature, Puppet.lookup(:current_environment))

    respond_to?(method) && self.send(method)
  end

  # Actually test whether the feature is present.  We only want to test when
  # someone asks for the feature, so we don't unnecessarily load
  # files.
  def test(name, options, &block)
    if block_given?
      begin
        result = yield
      rescue StandardError,ScriptError => detail
        warn _("Failed to load feature test for %{name}: %{detail}") % { name: name, detail: detail }
        result = nil
      end
      @results[name] = result
      result
    else
      libs = options[:libs]
      if libs
        libs = [libs] unless libs.is_a?(Array)
        libs.all? { |lib| load_library(lib, name) } ? true : nil
      else
        true
      end
    end
  end

  private

  def load_library(lib, name)
    raise ArgumentError, _("Libraries must be passed as strings not %{klass}") % { klass: lib.class } unless lib.is_a?(String)

    @rubygems ||= Puppet::Util::RubyGems::Source.new
    @rubygems.clear_paths

    begin
      require lib
      true
    rescue LoadError
      # Expected case. Required library insn't installed.
      debug_once(_("Could not find library '%{lib}' required to enable feature '%{name}'") %
        {lib: lib, name: name})
      false
    rescue StandardError, ScriptError => detail
      debug_once(_("Exception occurred while loading library '%{lib}' required to enable feature '%{name}': %{detail}") %
        {lib: lib, name: name, detail: detail})
      false
    end
  end
end
