require 'puppet'
require 'puppet/util/autoload'
require 'prettyprint'

class Puppet::Interface
  require 'puppet/interface/face_collection'

  require 'puppet/interface/action_manager'
  include Puppet::Interface::ActionManager
  extend Puppet::Interface::ActionManager

  require 'puppet/interface/option_manager'
  include Puppet::Interface::OptionManager
  extend Puppet::Interface::OptionManager

  include Puppet::Util

  class << self
    # This is just so we can search for actions.  We only use its
    # list of directories to search.
    # Can't we utilize an external autoloader, or simply use the $LOAD_PATH? -pvb
    def autoloader
      @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/face")
    end

    def faces
      Puppet::Interface::FaceCollection.faces
    end

    def register(instance)
      Puppet::Interface::FaceCollection.register(instance)
    end

    def define(name, version, &block)
      face = Puppet::Interface::FaceCollection[name, version]
      if face.nil? then
        face = self.new(name, version)
        Puppet::Interface::FaceCollection.register(face)
        # REVISIT: Shouldn't this be delayed until *after* we evaluate the
        # current block, not done before? --daniel 2011-04-07
        face.load_actions
      end

      face.instance_eval(&block) if block_given?

      return face
    end

    def face?(name, version)
      Puppet::Interface::FaceCollection[name, version]
    end

    def [](name, version)
      unless face = Puppet::Interface::FaceCollection[name, version]
        if current = Puppet::Interface::FaceCollection[name, :current]
          raise Puppet::Error, "Could not find version #{version} of #{name}"
        else
          raise Puppet::Error, "Could not find Puppet Face #{name.inspect}"
        end
      end
      face
    end
  end

  def set_default_format(format)
    Puppet.warning("set_default_format is deprecated (and ineffective); use render_as on your actions instead.")
  end

  ########################################################################
  # Documentation.  We currently have to rewrite both getters because we share
  # the same instance between build-time and the runtime instance.  When that
  # splits out this should merge into a module that both the action and face
  # include. --daniel 2011-04-17
  attr_accessor :summary
  def summary(value = nil)
    self.summary = value unless value.nil?
    @summary
  end
  def summary=(value)
    value = value.to_s
    value =~ /\n/ and
      raise ArgumentError, "Face summary should be a single line; put the long text in 'description' instead."

    @summary = value
  end

  attr_accessor :description
  def description(value = nil)
    self.description = value unless value.nil?
    @description
  end

  attr_accessor :examples
  def examples(value = nil)
    self.examples = value unless value.nil?
    @examples
  end

  attr_accessor :short_description
  def short_description(value = nil)
    self.short_description = value unless value.nil?
    if @short_description.nil? then
      fail "REVISIT: Extract this..."
    end
    @short_description
  end

  def author(value = nil)
    unless value.nil? then
      unless value.is_a? String
        raise ArgumentError, 'author must be a string; use multiple statements for multiple authors'
      end

      if value =~ /\n/ then
        raise ArgumentError, 'author should be a single line; use multiple statements for multiple authors'
      end
      @authors.push(value)
    end
    @authors.empty? ? nil : @authors.join("\n")
  end
  def author=(value)
    if Array(value).any? {|x| x =~ /\n/ } then
      raise ArgumentError, 'author should be a single line; use multiple statements'
    end
    @authors = Array(value)
  end
  def authors
    @authors
  end
  def authors=(value)
    if Array(value).any? {|x| x =~ /\n/ } then
      raise ArgumentError, 'author should be a single line; use multiple statements'
    end
    @authors = Array(value)
  end

  attr_accessor :notes
  def notes(value = nil)
    @notes = value unless value.nil?
    @notes
  end

  attr_accessor :license
  def license(value = nil)
    @license = value unless value.nil?
    @license
  end

  def copyright(owner = nil, years = nil)
    if years.nil? and not owner.nil? then
      raise ArgumentError, 'copyright takes the owners names, then the years covered'
    end
    self.copyright_owner = owner unless owner.nil?
    self.copyright_years = years unless years.nil?

    if self.copyright_years or self.copyright_owner then
      "Copyright #{self.copyright_years} by #{self.copyright_owner}"
    else
      "Unknown copyright owner and years."
    end
  end

  attr_accessor :copyright_owner
  def copyright_owner=(value)
    case value
    when String then @copyright_owner = value
    when Array  then @copyright_owner = value.join(", ")
    else
      raise ArgumentError, "copyright owner must be a string or an array of strings"
    end
    @copyright_owner
  end

  attr_accessor :copyright_years
  def copyright_years=(value)
    years = munge_copyright_year value
    years = (years.is_a?(Array) ? years : [years]).
      sort_by do |x| x.is_a?(Range) ? x.first : x end

    @copyright_years = years.map do |year|
      if year.is_a? Range then
        "#{year.first}-#{year.last}"
      else
        year
      end
    end.join(", ")
  end

  def munge_copyright_year(input)
    case input
    when Range then input
    when Integer then
      if input < 1970 then
        fault = "before 1970"
      elsif input > (future = Time.now.year + 2) then
        fault = "after #{future}"
      end
      if fault then
        raise ArgumentError, "copyright with a year #{fault} is very strange; did you accidentally add or subtract two years?"
      end

      input

    when String then
      input.strip.split(/,/).map do |part|
        part = part.strip
        if part =~ /^\d+$/ then
          part.to_i
        elsif found = part.split(/-/) then
          unless found.length == 2 and found.all? {|x| x.strip =~ /^\d+$/ }
            raise ArgumentError, "#{part.inspect} is not a good copyright year or range"
          end
          Range.new(found[0].to_i, found[1].to_i)
        else
          raise ArgumentError, "#{part.inspect} is not a good copyright year or range"
        end
      end

    when Array then
      result = []
      input.each do |item|
        item = munge_copyright_year item
        if item.is_a? Array
          result.concat item
        else
          result << item
        end
      end
      result

    else
      raise ArgumentError, "#{input.inspect} is not a good copyright year, set, or range"
    end
  end

  def synopsis
    output = PrettyPrint.format do |s|
      s.text("puppet #{name} <action>")
      s.breakable

      options.each do |option|
        option = get_option(option)
        wrap = option.required? ? %w{ < > } : %w{ [ ] }

        s.group(0, *wrap) do
          option.optparse.each do |item|
            unless s.current_group.first?
              s.breakable
              s.text '|'
              s.breakable
            end
            s.text item
          end
        end
      end
    end
  end


  ########################################################################
  attr_reader :name, :version

  def initialize(name, version, &block)
    unless Puppet::Interface::FaceCollection.validate_version(version)
      raise ArgumentError, "Cannot create face #{name.inspect} with invalid version number '#{version}'!"
    end

    @name    = Puppet::Interface::FaceCollection.underscorize(name)
    @version = version

    # The few bits of documentation we actually demand.  The default license
    # is a favour to our end users; if you happen to get that in a core face
    # report it as a bug, please. --daniel 2011-04-26
    @authors  = []
    @license  = 'All Rights Reserved'

    instance_eval(&block) if block_given?
  end

  # Try to find actions defined in other files.
  def load_actions
    Puppet::Interface.autoloader.search_directories.each do |dir|
      Dir.glob(File.join(dir, "puppet/face/#{name}", "*.rb")).each do |file|
        action = file.sub(dir, '').sub(/^[\\\/]/, '').sub(/\.rb/, '')
        Puppet.debug "Loading action '#{action}' for '#{name}' from '#{dir}/#{action}.rb'"
        require(action)
      end
    end
  end

  def to_s
    "Puppet::Face[#{name.inspect}, #{version.inspect}]"
  end

  ########################################################################
  # Action decoration, whee!  You are not expected to care about this code,
  # which exists to support face building and construction.  I marked these
  # private because the implementation is crude and ugly, and I don't yet know
  # enough to work out how to make it clean.
  #
  # Once we have established that these methods will likely change radically,
  # to be unrecognizable in the final outcome.  At which point we will throw
  # all this away, replace it with something nice, and work out if we should
  # be making this visible to the outside world... --daniel 2011-04-14
  private
  def __invoke_decorations(type, action, passed_args = [], passed_options = {})
    [:before, :after].member?(type) or fail "unknown decoration type #{type}"

    # Collect the decoration methods matching our pass.
    methods = action.options.select do |name|
      passed_options.has_key? name
    end.map do |name|
      action.get_option(name).__decoration_name(type)
    end

    methods.each do |hook|
      begin
        respond_to? hook and self.__send__(hook, action, passed_args, passed_options)
      rescue => e
        Puppet.warning("invoking #{action} #{type} hook: #{e}")
      end
    end
  end

  def __add_method(name, proc)
    meta_def(name, &proc)
    method(name).unbind
  end
  def self.__add_method(name, proc)
    define_method(name, proc)
    instance_method(name)
  end
end
