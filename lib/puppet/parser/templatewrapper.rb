require 'puppet/parser/files'
require 'erb'

# A simple wrapper for templates, so they don't have full access to
# the scope objects.
#
# @api private
class Puppet::Parser::TemplateWrapper
  include Puppet::Util
  Puppet::Util.logmethods(self)

  def initialize(scope)
    @__scope__ = scope
  end

  # @return [String] The full path name of the template that is being executed
  # @api public
  def file
    @__file__
  end

  # @return [Puppet::Parser::Scope] The scope in which the template is evaluated
  # @api public
  def scope
    @__scope__
  end

  # Find which line in the template (if any) we were called from.
  # @return [String] the line number
  # @api private
  def script_line
    identifier = Regexp.escape(@__file__ || "(erb)")
    (caller.find { |l| l =~ /#{identifier}:/ }||"")[/:(\d+):/,1]
  end
  private :script_line

  # Should return true if a variable is defined, false if it is not
  # @api public
  def has_variable?(name)
    scope.include?(name.to_s)
  end

  # @return [Array<String>] The list of defined classes
  # @api public
  def classes
    scope.catalog.classes
  end

  # @return [Array<String>] The tags defined in the current scope
  # @api public
  def tags
    scope.tags
  end

  # @return [Array<String>] All the defined tags
  # @api public
  def all_tags
    scope.catalog.tags
  end

  # Ruby treats variables like methods, so we used to expose variables
  # within scope to the ERB code via method_missing.  As per RedMine #1427,
  # though, this means that conflicts between methods in our inheritance
  # tree (Kernel#fork) and variable names (fork => "yes/no") could arise.
  #
  # Worse, /new/ conflicts could pop up when a new kernel or object method
  # was added to Ruby, causing templates to suddenly fail mysteriously when
  # Ruby was upgraded.
  #
  # To ensure that legacy templates using unqualified names work we retain
  # the missing_method definition here until we declare the syntax finally
  # dead.
  def method_missing(name, *args)
    line_number = script_line
    if scope.include?(name.to_s)
      Puppet.deprecation_warning("Variable access via '#{name}' is deprecated. Use '@#{name}' instead. #{to_s}:#{line_number}")
      return scope[name.to_s, { :file => @__file__, :line => line_number }]
    else
      # Just throw an error immediately, instead of searching for
      # other missingmethod things or whatever.
      raise Puppet::ParseError.new("Could not find value for '#{name}'", @__file__, line_number)
    end
  end

  # @api private
  def file=(filename)
    unless @__file__ = Puppet::Parser::Files.find_template(filename, scope.compiler.environment)
      raise Puppet::ParseError, "Could not find template '#{filename}'"
    end

    # We'll only ever not have a parser in testing, but, eh.
    scope.known_resource_types.watch_file(@__file__)
  end

  # @api private
  def result(string = nil)
    if string
      template_source = "inline template"
    else
      string = File.read(@__file__)
      template_source = @__file__
    end

    # Expose all the variables in our scope as instance variables of the
    # current object, making it possible to access them without conflict
    # to the regular methods.
    benchmark(:debug, "Bound template variables for #{template_source}") do
      scope.to_hash.each do |name, value|
        realname = name.gsub(/[^\w]/, "_")
        instance_variable_set("@#{realname}", value)
      end
    end

    result = nil
    benchmark(:debug, "Interpolated template #{template_source}") do
      template = ERB.new(string, 0, "-")
      template.filename = @__file__
      result = template.result(binding)
    end

    result
  end

  def to_s
    "template[#{(@__file__ ? @__file__ : "inline")}]"
  end
end
