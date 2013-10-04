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
        work.slice!(0, $MATCH.length)
      else
        res << work.slice!(0, textLen)
      end
    end
    res << work if work.length.nonzero?
    prefix + res.join("\n#{prefix}")
  end

  def header(txt, sep = "-")
    "\n#{txt}\n" + sep * txt.size
  end

  private

  def scrub(text)
    # For text with no carriage returns, there's nothing to do.
    return text if text !~ /\n/
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
      n = s.index(". ")
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
      docs[name] = type.attrclass(name).doc if attrs.include?(kind) && name != :provider
    end

    docs.sort { |a,b|
      a[0].to_s <=> b[0].to_s
    }.each { |name, doc|
      print "\n- **#{name}**"
      if type.key_attributes.include?(name) and name != :name
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
      params << name.to_s if attrs.include?(kind) && name != :provider
    end
    puts @format.wrap(params.sort.join(", "), :indent => 4)
  end

  def format_providers(type)
    type.providers.sort { |a,b|
      a.to_s <=> b.to_s
    }.each { |prov|
      puts "\n- **#{prov}**"
      puts @format.wrap(type.provider(prov).doc, :indent => 4, :scrub => true)
    }
  end

  def list_providers(type)
    list = type.providers.sort { |a,b|
      a.to_s <=> b.to_s
    }.join(", ")
    puts @format.wrap(list, :indent => 4)
  end

end

class Puppet::Application::Describe < Puppet::Application
  banner "puppet describe [options] [type]"

  option("--short", "-s", "Only list parameters without detail") do |arg|
    options[:parameters] = false
  end

  option("--providers","-p")
  option("--list", "-l")
  option("--meta","-m")

  def help
    <<-'HELP'

puppet-describe(8) -- Display help about resource types
========

SYNOPSIS
--------
Prints help about Puppet resource types, providers, and metaparameters.


USAGE
-----
puppet describe [-h|--help] [-s|--short] [-p|--providers] [-l|--list] [-m|--meta]


OPTIONS
-------
* --help:
  Print this help text

* --providers:
  Describe providers in detail for each type

* --list:
  List all types

* --meta:
  List all metaparameters

* --short:
  List only parameters without detail


EXAMPLE
-------
    $ puppet describe --list
    $ puppet describe file --providers
    $ puppet describe user -s -m


AUTHOR
------
David Lutterkort


COPYRIGHT
---------
Copyright (c) 2011 Puppet Labs, LLC Licensed under the Apache 2.0 License

    HELP
  end

  def preinit
    options[:parameters] = true
  end

  def main
    doc = TypeDoc.new

    if options[:list]
      doc.list_types
    else
      options[:types].each { |name| doc.format_type(name, options) }
    end
  end

  def setup
    options[:types] = command_line.args.dup
    handle_help(nil) unless options[:list] || options[:types].size > 0
    $stderr.puts "Warning: ignoring types when listing all types" if options[:list] && options[:types].size > 0
  end

end
