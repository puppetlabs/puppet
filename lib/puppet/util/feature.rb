#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

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
    raise ArgumentError, "Feature #{name} is already defined" if self.class.respond_to?(method)

    if block_given?
      begin
        result = yield
      rescue Exception => detail
        warn "Failed to load feature test for #{name}: #{detail}"
        result = false
      end
      @results[name] = result
    end

    meta_def(method) do
      @results[name] = test(name, options) unless @results.include?(name)
      @results[name]
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
    raise ArgumentError, "Libraries must be passed as strings not #{lib.class}" unless lib.is_a?(String)

    begin
      require lib
    rescue SystemExit,NoMemoryError
      raise
    rescue Exception
      Puppet.debug "Failed to load library '#{lib}' for feature '#{name}'"
      return false
    end
    true
  end
end
