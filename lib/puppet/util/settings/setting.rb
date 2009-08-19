# The base element type.
class Puppet::Util::Settings::Setting
    attr_accessor :name, :section, :default, :setbycli, :call_on_define
    attr_reader :desc, :short

    def desc=(value)
        @desc = value.gsub(/^\s*/, '')
    end

    # get the arguments in getopt format
    def getopt_args
        if short
            [["--#{name}", "-#{short}", GetoptLong::REQUIRED_ARGUMENT]]
        else
            [["--#{name}", GetoptLong::REQUIRED_ARGUMENT]]
        end
    end

    # get the arguments in OptionParser format
    def optparse_args
        if short
            ["--#{name}", "-#{short}", desc, :REQUIRED]
        else
            ["--#{name}", desc, :REQUIRED]
        end
    end

    def hook=(block)
        meta_def :handle, &block
    end

    # Create the new element.  Pretty much just sets the name.
    def initialize(args = {})
        unless @settings = args.delete(:settings)
            raise ArgumentError.new("You must refer to a settings object")
        end

        args.each do |param, value|
            method = param.to_s + "="
            unless self.respond_to? method
                raise ArgumentError, "%s does not accept %s" % [self.class, param]
            end

            self.send(method, value)
        end

        unless self.desc
            raise ArgumentError, "You must provide a description for the %s config option" % self.name
        end
    end

    def iscreated
        @iscreated = true
    end

    def iscreated?
        if defined? @iscreated
            return @iscreated
        else
            return false
        end
    end

    def set?
        if defined? @value and ! @value.nil?
            return true
        else
            return false
        end
    end

    # short name for the celement
    def short=(value)
        if value.to_s.length != 1
            raise ArgumentError, "Short names can only be one character."
        end
        @short = value.to_s
    end

    # Convert the object to a config statement.
    def to_config
        str = @desc.gsub(/^/, "# ") + "\n"

        # Add in a statement about the default.
        if defined? @default and @default
            str += "# The default value is '%s'.\n" % @default
        end

        # If the value has not been overridden, then print it out commented
        # and unconverted, so it's clear that that's the default and how it
        # works.
        value = @settings.value(self.name)

        if value != @default
            line = "%s = %s" % [@name, value]
        else
            line = "# %s = %s" % [@name, @default]
        end

        str += line + "\n"

        str.gsub(/^/, "    ")
    end

    # Retrieves the value, or if it's not set, retrieves the default.
    def value
        @settings.value(self.name)
    end
end

