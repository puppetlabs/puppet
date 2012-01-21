# This isn't usable outside Puppet::Interface; don't load it alone.
class Puppet::Interface
  module DocGen
    def self.strip_whitespace(text)
      text.gsub!(/[ \t\f]+$/, '')

      # We need to identify an indent: the minimum number of whitespace
      # characters at the start of any line in the text.
      #
      # Using split rather than each_line is because the later only takes a
      # block on Ruby 1.8.5 / Centos, and we support that. --daniel 2011-05-03
      indent = text.split(/\n/).map {|x| x.index(/[^\s]/) }.compact.min

      if indent > 0 then
        text.gsub!(/^[ \t\f]{0,#{indent}}/, '')
      end

      return text
    end

    # The documentation attributes all have some common behaviours; previously
    # we open-coded them across the set of six things, but that seemed
    # wasteful - especially given that they were literally the same, and had
    # the same bug hidden in them.
    #
    # This feels a bit like overkill, but at least the common code is common
    # now. --daniel 2011-04-29
    def attr_doc(name, &validate)
      # Now, which form of the setter do we want, validated or not?
      get_arg = "value.to_s"
      if validate
        define_method(:"_validate_#{name}", validate)
        get_arg = "_validate_#{name}(#{get_arg})"
      end

      # We use module_eval, which I don't like much, because we can't have an
      # argument to a block with a default value in Ruby 1.8, and I don't like
      # the side-effects (eg: no argument count validation) of using blocks
      # without as metheds.  When we are 1.9 only (hah!) you can totally
      # replace this with some up-and-up define_method. --daniel 2011-04-29
      module_eval(<<-EOT, __FILE__, __LINE__ + 1)
        def #{name}(value = nil)
          self.#{name} = value unless value.nil?
          @#{name}
        end

        def #{name}=(value)
          @#{name} = Puppet::Interface::DocGen.strip_whitespace(#{get_arg})
        end
      EOT
    end
  end

  module TinyDocs
    extend Puppet::Interface::DocGen

    attr_doc :summary do |value|
      value =~ /\n/ and
        raise ArgumentError, "Face summary should be a single line; put the long text in 'description' instead."
      value
    end

    attr_doc :description

    def build_synopsis(face, action = nil, arguments = nil)
      output = PrettyPrint.format do |s|
        s.text("puppet #{face}")
        s.text(" #{action}") unless action.nil?
        s.text(" ")

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

          s.breakable
        end

        if arguments then
          s.text arguments.to_s
        end
      end
    end

  end

  module FullDocs
    extend Puppet::Interface::DocGen
    include TinyDocs

    attr_doc :examples
    attr_doc :notes
    attr_doc :license

    attr_doc :short_description
    def short_description(value = nil)
      self.short_description = value unless value.nil?
      if @short_description.nil? then
        return nil if @description.nil?
        lines = @description.split("\n")
        first_paragraph_break = lines.index('') || 5
        grab  = [5, first_paragraph_break].min
        @short_description = lines[0, grab].join("\n")
        @short_description += ' [...]' if (grab < lines.length and first_paragraph_break >= 5)
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
        @authors.push(Puppet::Interface::DocGen.strip_whitespace(value))
      end
      @authors.empty? ? nil : @authors.join("\n")
    end
    def authors
      @authors
    end
    def author=(value)
      if Array(value).any? {|x| x =~ /\n/ } then
        raise ArgumentError, 'author should be a single line; use multiple statements'
      end
      @authors = Array(value).map{|x| Puppet::Interface::DocGen.strip_whitespace(x) }
    end
    alias :authors= :author=

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
  end
end
