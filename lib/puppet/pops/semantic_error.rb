# Error that is used to raise an Issue. See {Puppet::Pops::Issues}.
#
class Puppet::Pops::SemanticError < RuntimeError
  attr_accessor :issue
  attr_accessor :semantic
  attr_accessor :options

  # @param issue [Puppet::Pops::Issues::Issue] the issue describing the severity and message
  # @param semantic [Puppet::Pops::Model::Locatable, nil] the expression causing the failure, or nil if unknown
  # @param options [Hash] an options hash with Symbol to value mapping - these are the arguments to the issue
  #
  def initialize(issue, semantic=nil, options = {})
    @issue = issue
    @semantic = semantic
    @options = options
  end

  def file
    @options[:file]
  end

  def line
    @options[:line]
  end

  def pos
    @options[:pos]
  end
end
