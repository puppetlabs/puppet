require 'puppet'
require 'puppet/application'

class Formatter

    def initialize(width)
        @width = width
    end

    def wrap(txt, opts)
        return "" unless txt && !txt.empty?
        work = (opts[:scrub] ? scrub(txt) : txt)
        indent = (opts[:indent] ? opts[:indent] : 0)
        textLen = @width - indent
        patt = Regexp.new("^(.{0,#{textLen}})[ \n]")
        prefix = " " * indent

        res = []

        while work.length > textLen
            if work =~ patt
                res << $1
                work.slice!(0, $&.length)
            else
                res << work.slice!(0, textLen)
            end
        end
        res << work if work.length.nonzero?
        return prefix + res.join("\n" + prefix)
    end

    def header(txt, sep = "-")
        "\n#{txt}\n" + sep * txt.size
    end

    private

    def scrub(text)
        # For text with no carriage returns, there's nothing to do.
        if text !~ /\n/
            return text
        end
        indent = nil

        # If we can match an indentation, then just remove that same level of
        # indent from every line.
        if text =~ /^(\s+)/
            indent = $1
            return text.gsub(/^#{indent}/,'')
        else
            return text
        end
    end

end

class TypeDoc

    def initialize
        @format = Formatter.new(76)
        @types = {}
        Puppet::Type.loadall
        Puppet::Type.eachtype { |type|
            next if type.name == :component
            @types[type.name] = type
        }
    end

    def list_types
        puts "These are the types known to puppet:\n"
        @types.keys.sort { |a, b|
            a.to_s <=> b.to_s
        }.each do |name|
            type = @types[name]
            s = type.doc.gsub(/\s+/, " ")
            n = s.index(".")
            if n.nil?
                s = ".. no documentation .."
            elsif n > 45
                s = s[0, 45] + " ..."
            else
                s = s[0, n]
            end
            printf "%-15s - %s\n", name, s
        end
    end

    def format_type(name, opts)
        name = name.to_sym
        unless @types.has_key?(name)
            puts "Unknown type #{name}"
            return
        end
        type = @types[name]
        puts @format.header(name.to_s, "=")
        puts @format.wrap(type.doc, :indent => 0, :scrub => true) + "\n\n"

        puts @format.header("Parameters")
        if opts[:parameters]
            format_attrs(type, [:property, :param])
        else
            list_attrs(type, [:property, :param])
        end

        if opts[:meta]
            puts @format.header("Meta Parameters")
            if opts[:parameters]
                format_attrs(type, [:meta])
            else
                list_attrs(type, [:meta])
            end
        end

        if type.providers.size > 0
            puts @format.header("Providers")
            if opts[:providers]
                format_providers(type)
            else
                list_providers(type)
            end
        end
    end

    # List details about attributes
    def format_attrs(type, attrs)
        docs = {}
        type.allattrs.each do |name|
            kind = type.attrtype(name)
            if attrs.include?(kind) && name != :provider
                docs[name] = type.attrclass(name).doc
            end
        end

        docs.sort { |a,b|
            a[0].to_s <=> b[0].to_s
        }.each { |name, doc|
            print "\n- **%s**" % name
            if type.namevar == name and name != :name
                puts " (*namevar*)"
            else
                puts ""
            end
            puts @format.wrap(doc, :indent => 4, :scrub => true)
        }
    end

    # List the names of attributes
    def list_attrs(type, attrs)
        params = []
        type.allattrs.each do |name|
            kind = type.attrtype(name)
            if attrs.include?(kind) && name != :provider
                params << name.to_s
            end
        end
        puts @format.wrap(params.sort.join(", "), :indent => 4)
    end

    def format_providers(type)
        type.providers.sort { |a,b|
            a.to_s <=> b.to_s
        }.each { |prov|
            puts "\n- **%s**" % prov
            puts @format.wrap(type.provider(prov).doc,
                              :indent => 4, :scrub => true)
        }
    end

    def list_providers(type)
        list = type.providers.sort { |a,b|
            a.to_s <=> b.to_s
        }.join(", ")
        puts @format.wrap(list, :indent => 4)
    end

end

Puppet::Application.new(:pi,"#{$0} [options] [type]") do

    should_not_parse_config

    option("--short", "-s", "Only list parameters without detail") do |arg|
        options[:parameters] = false
    end

    option("--providers","-p")
    option("--list", "-l")
    option("--meta","-m")

    preinit do
        options[:parameters] = true
    end

    command(:main) do
        doc = TypeDoc.new

        if options[:list]
            doc.list_types
        else
            options[:types].each { |name| doc.format_type(name, options) }
        end
    end

    setup do
        options[:types] = ARGV.dup
        unless options[:list] || options[:types].size > 0
            handle_help(nil)
        end
        if options[:list] && options[:types].size > 0
            $stderr.puts "Warning: ignoring types when listing all types"
        end
    end

end
