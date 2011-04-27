class Puppet::Interface
  module DocSupport
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
        return nil if @description.nil?
        lines = @description.split("\n")
        grab  = [5, lines.index('') || 5].min
        @short_description = lines[0, grab].join("\n")
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
  end
end
