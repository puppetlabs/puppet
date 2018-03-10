# This represents an option on an action or face (to be globally applied
# to its actions). Options should be constructed by calling
# {Puppet::Interface::OptionManager#option}, which is available on
# {Puppet::Interface}, and then calling methods of
# {Puppet::Interface::OptionBuilder} in the supplied block.
# @api public
class Puppet::Interface::Option
  include Puppet::Interface::TinyDocs

  # @api private
  def initialize(parent, *declaration, &block)
    @parent   = parent
    @optparse = []
    @default  = nil

    # Collect and sort the arguments in the declaration.
    dups = {}
    declaration.each do |item|
      if item.is_a? String and item.to_s =~ /^-/ then
        unless item =~ /^-[a-z]\b/ or item =~ /^--[^-]/ then
          raise ArgumentError, _("%{option}: long options need two dashes (--)") % { option: item.inspect }
        end
        @optparse << item

        # Duplicate checking...
        # for our duplicate checking purpose, we don't make a check with the
        # translated '-' -> '_'. Right now, we do that on purpose because of
        # a duplicated option made publicly available on certificate and ca
        # faces for dns alt names. Puppet defines 'dns_alt_names', those
        # faces include 'dns-alt-names'.  We can't get rid of 'dns-alt-names'
        # yet, so we need to do our duplicate checking on the untranslated
        # version of the option.
        # jeffweiss 17 april 2012
        name = optparse_to_optionname(item)
        if Puppet.settings.include? name then
          raise ArgumentError, _("%{option}: already defined in puppet") % { option: item.inspect }
        end
        if dup = dups[name] then
          raise ArgumentError, _("%{option}: duplicates existing alias %{duplicate} in %{parent}") %
              { option: item.inspect, duplicate: dup.inspect, parent: @parent }
        else
          dups[name] = item
        end
      else
        raise ArgumentError, _("%{option} is not valid for an option argument") % { option: item.inspect }
      end
    end

    if @optparse.empty? then
      raise ArgumentError, _("No option declarations found while building")
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
      raise ArgumentError, _("Option %{name} is inconsistent about taking an argument") % { name: @name }
    end

    # Is our argument optional?  The rules about consistency apply here, also,
    # just like they do to taking arguments at all. --daniel 2011-03-30
    @optional_argument = @optparse.any? { |o| o=~/[ =]\[/ }
    if @optional_argument
      raise ArgumentError, _("Options with optional arguments are not supported")
    end
    if @optional_argument and not @optparse.all? { |o| o=~/[ =]\[/ } then
      raise ArgumentError, _("Option %{name} is inconsistent about the argument being optional") % { name: @name }
    end
  end

  # to_s and optparse_to_name are roughly mirrored, because they are used to
  # transform options to name symbols, and vice-versa.  This isn't a full
  # bidirectional transformation though. --daniel 2011-04-07

  def to_s
    @name.to_s.tr('_', '-')
  end

  # @api private
  def optparse_to_optionname(declaration)
    unless found = declaration.match(/^-+(?:\[no-\])?([^ =]+)/) then
      raise ArgumentError, _("Can't find a name in the declaration %{declaration}") % { declaration: declaration.inspect }
    end
    found.captures.first
  end

  # @api private
  def optparse_to_name(declaration)
    name = optparse_to_optionname(declaration).tr('-', '_')
    unless name.to_s =~ /^[a-z]\w*$/
      raise _("%{name} is an invalid option name") % { name: name.inspect }
    end
    name.to_sym
  end


  def takes_argument?
    !!@argument
  end
  def optional_argument?
    !!@optional_argument
  end
  def required?
    !!@required
  end

  def has_default?
    !!@default
  end

  def default=(proc)
    if required
      raise ArgumentError, _("%{name} can't be optional and have a default value") % { name: self }
    end
    unless proc.is_a? Proc
      #TRANSLATORS 'proc' is a Ruby block of code
      raise ArgumentError, _("default value for %{name} is a %{class_name}, not a proc") %
          { name: self, class_name: proc.class.name.inspect }
    end
    @default = proc
  end

  def default
    @default and @default.call
  end

  attr_reader   :parent, :name, :aliases, :optparse
  attr_accessor :required
  def required=(value)
    if has_default?
      raise ArgumentError, _("%{name} can't be optional and have a default value") % { name: self }
    end
    @required = value
  end

  attr_accessor :before_action
  def before_action=(proc)
    unless proc.is_a? Proc
      #TRANSLATORS 'proc' is a Ruby block of code
      raise ArgumentError, _("before action hook for %{name} is a %{class_name}, not a proc") %
          { name: self, class_name: proc.class.name.inspect }
    end
    @before_action =
      @parent.__send__(:__add_method, __decoration_name(:before), proc)
  end

  attr_accessor :after_action
  def after_action=(proc)
    unless proc.is_a? Proc
      #TRANSLATORS 'proc' is a Ruby block of code
      raise ArgumentError, _("after action hook for %{name} is a %{class_name}, not a proc") %
          { name: self, class_name: proc.class.name.inspect }
    end
    @after_action =
      @parent.__send__(:__add_method, __decoration_name(:after), proc)
  end

  def __decoration_name(type)
    if @parent.is_a? Puppet::Interface::Action then
      :"option #{name} from #{parent.name} #{type} decoration"
    else
      :"option #{name} #{type} decoration"
    end
  end
end
