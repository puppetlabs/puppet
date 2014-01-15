require 'puppet/util/package'
require 'fileutils'

module Puppet::Util::Package::Ports
  # Maintain FreeBSD ports options  (normally settable with `make search`).
  #
  # This is just a hash with simple validation and few additional methods for
  # loading, parsing and saving ports options to a file.
  #
  # ### Options as a validating hash
  #
  # The hash accepts Strings or Symbols as keys. When entering the hash, keys
  # are validated against a regexp accepting only well-formed identifiers
  # (`/^[a-zA-Z_]\w*$/`). The values must be either `true`/`false` boolean
  # values, `:on`/`:off` symbols or `'on'`/`'off'` strings. If validation
  # fails an exception is raised. The class uses
  # [vash](https://github.com/ptomulik/puppet-vash) module to enforce
  # validation and munging, and it is vash who defines the exceptions being
  # raised.
  #
  # Keys and values are internally munged, such that all input keys get
  # converted to symbols and input values to booleans. For example:
  #
  #     require 'puppet/util/package/ports/options'
  #     opts = Puppet::Util::Package::Ports::Options.new
  #     opts['FOO'] = 'off'
  #     puts opts.inspect
  #
  # would print `{:FOO=>false}`.
  #
  # ### Loading and saving options
  #
  # Options can be loaded from FreeBSD port options files or extracted from a
  # string. They may be further converted to a string or saved to a file. The
  # class provides following methods for that:
  # 
  # - {load} - load options from files,
  # - {parse} - extract options from a string,
  # - {#generate} - store options to a string,
  # - {#save} - save options to a file.
  #
  class Options

    # Module from ptomulik/vash puppet plugin
    require 'puppet/util/vash/contained'
    include Puppet::Util::Vash::Contained

    # Is x valid as option name?
    #
    # @param x an input value to be checked
    # @return [Boolean] `true` if `x` is a valid option name, `false` if not.
    def self.option_name?(x)
      x = x.to_s if x.is_a?(Symbol)
      x.is_a?(String) and x =~ /^[a-zA-Z_]\w*$/
    end

    # Is x valid as option value?
    #
    # @param x an input value to be checked
    # @return [Boolean] `true` if `x` is a valid option value, `false` if not
    #
    def self.option_value?(x)
      ['on', 'off', :on, :off, true, false].include?(x)
    end

    # Convert valid option names to symbols
    #
    # @param name [String|Symbol] input name to be munged
    # @return [Symbol] the `name` converted to Symbol
    #
    def self.munge_option_name(name)
      # note, on 1.8 Symbol has no :intern method
      name.is_a?(String) ? name.intern : name
    end

    # Convert valid option values (strings, symbols) to boolean values
    #
    # @param value [String|Symbol|Boolean] input value to be munged,
    # @return [Boolean] `true` if the `value` is `true`, `:on`, or `on`;
    #   otherwise `false` 
    #
    def self.munge_option_value(value)
      case value
      when 'on', :on, true; true
      else; false
      end
    end

    # --
    # Overriden methods from Vash::Contained
    # ++
    
    # Required by Vash to have key validation in place.
    def vash_valid_key?(x);     self.class.option_name?(x);          end
    # Required by Vash to have value validation in place.
    def vash_valid_value?(x);   self.class.option_value?(x);         end
    # Required by Vash to have key munging in place.
    def vash_munge_key(key);    self.class.munge_option_name(key);   end
    # Required by Vash to have value munging in place.
    def vash_munge_value(val);  self.class.munge_option_value(val);  end
    # Used by Vash as a key name.
    def vash_key_name(*args);   'option name';                       end
    # Used by Vash as to generate exceptions for invalid option values.
    def vash_value_exception(val,*args)
      name = vash_value_name(val,*args)
      msg  = "invalid value #{val.inspect}"
      msg += " at position  #{args[0].inspect}" unless args[0].nil?
      msg += " for option #{args[1].to_s}" unless args.length < 2
      [Puppet::Util::Vash::InvalidValueError, msg]
    end


    # Parse string for options.
    #
    # @param string [String] a content of options file to be scanned for
    #   options,
    # @return [Puppet::Util::Package::Ports::Options] new instance
    #   of Options.
    def self.parse(string)
      opt_re = /^\s*OPTIONS_FILE_((?:UN)?SET)\s*\+=(\w+)\s*$/
      Options[ string.scan(opt_re).map{|pair| [pair[1], pair[0]=='SET']} ]
    end

    # Read options from options files. Missing files from __files__ list are
    # ignored by default.
    #
    # @param files [String|Array] file name (or array of file names) to be
    #   scanned for ports options, the files get loaded in order specified in
    #   __files__ array; options found in later files overwrite the earlier
    #   options,
    # @param params [Hash] additional parameters to alter method behavior
    # @option params :all [Boolean] load options from all files listed in
    #   __files__ (don't skip missing files), if a file is missing the method
    #   will fail with an exception instead of silently ignoring missing files,
    def self.load(files,params={})
      files = [files] unless files.is_a?(Array)
      # concatenate all files in order ...
      contents = []
      files.each do|file|
        next if (not File.exists?(file)) and not params[:all]
        msg = "Reading port options from '#{file}'"
        respond_to?(:debug) ? debug(msg) : Puppet.debug(msg)
        contents << File.read(file)
      end
      parse(contents.join("\n"))
    end

    self::PKG_ARGS_MAX = 60

    # Query pkgng for package options. 
    #
    # This method executes 
    #
    #     pkg query "#{key} %Ok %Ov" ...
    #
    # to extract package options for (a list of) installed package(s). See
    # pkg-query(8) for query formats used by `pkg query`.
    #
    # @param key [String] determines what will be used as keys in the returned
    #   hash; example values are `'%n'` - return *pkgnames* in keys, `'%o'`
    #   return *pkgorigins* in keys, 
    # @param packages [Array] list of packages to be queried; if not given,
    #   query all the installed packages,
    # @param params [Hash] additional parameters to alter method's behavior,
    # @option params :execpipe [Method] handle to a method which provides
    #   `execpipe` functionality, should have same interface as
    #   `Puppet::Util::Execution#execpipe`,
    # @option params :pkg [String] absolute path to the `pkg` command,
    # @return [Hash] a hash in form `{'package'=>{'OPTION'=>value,...}, ... }`,
    #   what is put in keys (`'package'` in the above example) depends on the
    #   __key__ argument,
    #
    def self.query_pkgng(key,packages=nil,params={})
      options = {}
      if packages
        packages.each_slice(self::PKG_ARGS_MAX) do |slice|
          query_pkgng_1(key,slice,params) { |hash| options.merge!(hash) }
        end
      else
        query_pkgng_1(key,[],params) {|hash| options.merge!(hash) }
      end
      options
    end

    # @api private
    def self.query_pkgng_1(key,slice,params)
      pkg = params[:pkg] || 'pkg'
      cmd = [pkg, 'query', "'#{key} %Ok %Ov'"] + slice
      execpipe = params[:execpipe] || Puppet::Util::Execution.method(:execpipe)
      options = {}
      execpipe.call(cmd) do |pipe|
        pipe.each_line do |line|
          origin, option, value = line.strip.split
          options[origin] ||= new
          options[origin][option] = value
        end
      end
      yield options
    end
    private_class_method :query_pkgng_1

    # Write to a string all the options in form suitable to be saved as an
    # options file. This is symmetric to what {parse} does.
    #
    # @param params [Hash] hash of parameters to alter method's behavior
    # @option params :pkgname [String] package name to which the options apply,
    #   by convention it should be a *pkgname* of the given package.
    # @return [String] the generated content as string.
    #
    def generate(params)
      content  = "# This file is auto-generated by puppet\n"
      if params[:pkgname]
        content += "# Options for #{params[:pkgname]}\n"
        content += "_OPTIONS_READ=#{params[:pkgname]}\n"
      end
      keys.sort.each do |k|
        v = self[k]
        content += "OPTIONS_FILE_#{v ? '':'UN'}SET+=#{k}\n"
      end
      content
    end

    # Save package options to options file.
    #
    # @param [String] file path to options' file.
    # @param [Hash] params additional parameters to function
    #
    # @option params :pkgname [String] package name to which the options apply,
    #   by convention it should be a *pkgname* of the given package,
    # @option params :mkdir_p [Boolean] create directories recursively if they
    #   don't exist; if `false`, only last level subdirectory is allowed to be
    #   created.
    # @note by default we do not allow to create directories recursivelly;
    #       we assume, that '/var/db/ports' already exists and user saves
    #       its options to '/var/db/ports/my_port/options';
    #
    def save(file,params={})
      dir = File.dirname(file)
      if not File.exists?(dir)
        msg = "Creating directory #{dir}"
        respond_to?(:debug) ? debug(msg) : Puppet.debug(msg)
        params[:mkdir_p] ?  FileUtils.mkdir_p(dir) : Dir.mkdir(dir)
      end
      msg = params[:pkgname] ?
        "Saving options for '#{params[:pkgname]}' port to file '#{file}'" :
        "Saving port options to file '#{file}'"
      respond_to?(:debug) ? debug(msg) : Puppet.debug(msg)
      File.write(file,generate(params))
    end

  end
end
