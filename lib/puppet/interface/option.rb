require 'puppet/interface'

class Puppet::Interface::Option
  attr_reader   :parent
  attr_reader   :name
  attr_reader   :aliases
  attr_reader   :optparse
  attr_accessor :desc

  def takes_argument?
    !!@argument
  end
  def optional_argument?
    !!@optional_argument
  end

  def initialize(parent, *declaration, &block)
    @parent   = parent
    @optparse = []

    # Collect and sort the arguments in the declaration.
    dups = {}
    declaration.each do |item|
      if item.is_a? String and item.to_s =~ /^-/ then
        unless item =~ /^-[a-z]\b/ or item =~ /^--[^-]/ then
          raise ArgumentError, "#{item.inspect}: long options need two dashes (--)"
        end
        @optparse << item

        # Duplicate checking...
        name = optparse_to_name(item)
        if dup = dups[name] then
          raise ArgumentError, "#{item.inspect}: duplicates existing alias #{dup.inspect} in #{@parent}"
        else
          dups[name] = item
        end
      else
        raise ArgumentError, "#{item.inspect} is not valid for an option argument"
      end
    end

    if @optparse.empty? then
      raise ArgumentError, "No option declarations found while building"
    end

    # Now, infer the name from the options; we prefer the first long option as
    # the name, rather than just the first option.
    @name = optparse_to_name(@optparse.find do |a| a =~ /^--/ end || @optparse.first)
    @aliases = @optparse.map { |o| optparse_to_name(o) }

    # Do we take an argument?  If so, are we consistent about it, because
    # incoherence here makes our life super-difficult, and we can more easily
    # relax this rule later if we find a valid use case for it. --daniel 2011-03-30
    @argument = @optparse.any? { |o| o =~ /[ =]/ }
    if @argument and not @optparse.all? { |o| o =~ /[ =]/ } then
      raise ArgumentError, "Option #{@name} is inconsistent about taking an argument"
    end

    # Is our argument optional?  The rules about consistency apply here, also,
    # just like they do to taking arguments at all. --daniel 2011-03-30
    @optional_argument = @optparse.any? { |o| o.include? "[" }
    if @optional_argument and not @optparse.all? { |o| o.include? "[" } then
      raise ArgumentError, "Option #{@name} is inconsistent about the argument being optional"
    end
  end

  # to_s and optparse_to_name are roughly mirrored, because they are used to
  # transform options to name symbols, and vice-versa.  This isn't a full
  # bidirectional transformation though. --daniel 2011-04-07
  def to_s
    @name.to_s.tr('_', '-')
  end

  def optparse_to_name(declaration)
    unless found = declaration.match(/^-+(?:\[no-\])?([^ =]+)/) then
      raise ArgumentError, "Can't find a name in the declaration #{declaration.inspect}"
    end
    name = found.captures.first.tr('-', '_')
    raise "#{name.inspect} is an invalid option name" unless name.to_s =~ /^[a-z]\w*$/
    name.to_sym
  end
end
