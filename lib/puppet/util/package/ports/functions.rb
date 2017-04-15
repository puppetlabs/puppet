require 'puppet/util/package'

module Puppet::Util::Package::Ports
# Stuff used commonly by other ports-related modules.
#
# @note To gather certain information the module uses `ENV`, Facter and runs
#   external commands.
#
# The content of the module is described in the following subsections.
#
# #### Validating package names etc.
#
# To check whether a given value constitutes valid *portorigin*, *portname*,
# or *pkgname*, the following methods may be used:
#
# - {#portorigin?},
# - {#portname?},
# - {#pkgname?}.
#
# The module also defines constants containing regular expressions that may
# be used to validate *portorigins*, *pkgnames*, *portnames* etc.. These are:
#
# - {PORTNAME_RE},
# - {PKGNAME_RE},
# - {PORTORIGIN_RE},
# - {PORTVERSION_RE}.
#
# Note that these regexps are not mutually exclusive. Certain strings may
# match {PKGNAME_RE} and {PORTNAME_RE} simultaneously, for example.
#
# #### Preparing search patterns for `make search` command
#
# The {Puppet::Util::Package::Ports::PortSearch} module defines
# several methods to search ports' INDEX. They accept (lists of) *portnames*,
# *pkgnames*, *portorigins*, etc., as search keys. The `make search` back-end
# command, however, needs to be provided with a search pattern that is a kind
# of regular expression. The search pattern may describe multiple ports at
# once. That said, the external command may query information for multiple
# packages at once. The search pattern must be thus properly constructed to
# generate expected search queries. The following methods are involved in
# pattern creation:
#
# - {#escape_pattern},
# - {#strings_to_pattern},
# - {#fullname_to_pattern},
# - {#pkgname_to_pattern},
# - {#portorigin_to_pattern},
# - {#portname_to_pattern},
# - {#mk_search_pattern},
#
# #### Determining location of port directories and type of database
#
# There are also methods returning (default) locations of ports tree and
# the root of ports database in a file system. These are:
#
# - {#portsdir},
# - {#port_dbdir}.
#
# There is also a method to check whether a local OS uses
# [pkgng](https://wiki.freebsd.org/pkgng), see:
#
# - {#pkgng_active?}.
#
module Functions

  # Regular expression used to match portname.
  PORTNAME_RE    = /[a-zA-Z0-9][\w\.+-]*/
  # Regular expression used to match package version suffix.
  PORTVERSION_RE = /[a-zA-Z0-9][\w\.,]*/
  # Regular expression used to match pkgname.
  PKGNAME_RE     = /(#{PORTNAME_RE})-(#{PORTVERSION_RE})/
  # Regular expression used to match portorigin.
  PORTORIGIN_RE  = /(#{PORTNAME_RE})\/(#{PORTNAME_RE})/

  # Is this a well-formed port's origin?
  #
  # @param s the value to be verified
  # @return [Boolean] `true` if `s` is a `String` and contains well-formed
  #   *portorigin*, `false` otherwise,
  #
  def portorigin?(s)
    s.is_a?(String) and s =~ /^#{PORTORIGIN_RE}$/
  end

  # Is this a well-formed port's pkgname?
  #
  # @param s the value to be verified
  # @return [Boolean] `true` if `s` is a `String` and contains well-formed
  #   *pkgname*, `false` othrewise
  #
  def pkgname?(s)
    s.is_a?(String) and s =~ /^#{PKGNAME_RE}$/
  end

  # Is this a well-formed portname?
  #
  # @param s the value to be verified
  # @return [Boolean] `true` if `s` is a `String` and contains well-formed
  #   *portname*, `false` otherwise
  #
  def portname?(s)
    s.is_a?(String) and s =~ /^#{PORTNAME_RE}$/
  end

  # Split *pkgname* into *portname* and *portversion*.
  #
  # @param pkgname [String] the name to be split
  # @return [Array] a 2-element array: `[portname,portversion]`; if the input
  #   string `pkgname` cannot be split into *portname* and *portversion*, the
  #   function still returns a 2-element array in form `[pkgname,nil]`
  #
  def split_pkgname(pkgname)
    if m = /^#{PKGNAME_RE}$/.match(pkgname)
      m.captures
    else
      [pkgname, nil]
    end
  end

  # Escape string that is to be used as a search pattern.
  #
  # This method converts all characters that could be interpreted as regex
  # special characters to corresponding escape sequences.
  #
  # @note The resultant pattern is a search pattern for an external CLI
  #   command and not a ruby regexp (it's a string in fact).
  # @param pattern [String] the search pattern to be escaped
  # @return [String] escaped pattern.
  #
  def escape_pattern(pattern)
    # it's also advisable to validate user's input with pkgname?, portname? or
    # potorigin?
    pattern.gsub(/([\(\)\.\*\[\]\|])/) {|c| '\\' + c}
  end

  # Convert a search key (or an array of keys) to a search pattern for `"make
  # search"` command.
  #
  # If `s` is a string, it's just escaped with {#escape_pattern} and returned.
  # If it's a sequence of strings, then the function returns a pattern matching
  # any of them.
  #
  # @note The resultant pattern is a search pattern for an external CLI
  #   command and not a ruby regexp (it's a string in fact).
  # @param s [String|Enumerable] a string or an array of strings to be
  #   converted to a search pattern
  # @return [String] the resultant search pattern 
  #
  def strings_to_pattern(s)
    if s.is_a?(Enumerable) and not s.instance_of?(String)
      '(' + s.map{|p| escape_pattern(p)}.join('|') + ')'
    else
      escape_pattern(s)
    end
  end

  # Convert a full package name to search pattern for the `make search` command.
  #
  # @param names [String|Enumerable] the name or names to be turned into
  #   search pattern,
  # @return [String] the resultant pattern
  # @see #strings_to_pattern
  #
  def fullname_to_pattern(names)
    "^#{strings_to_pattern(names)}$"
  end

  # Convert *portorigins* to search pattern for the `make search` command.
  #
  # @param origins [String|Enumerable] the *portorigin* or *portorigins* to be
  #   turned into search pattern,
  # @return [String] the resultant pattern
  # @see #strings_to_pattern
  #
  def portorigin_to_pattern(origins)
    "^#{portsdir}/#{strings_to_pattern(origins)}$"
  end

  # Convert *pkgnames* to search pattern for the `make search` command.
  #
  # @param pkgnames [String|Enumerable] the *pkgname* or *pkgnames* to be
  #   turned into search patterns,
  # @return [String] the resultant pattern
  # @see #strings_to_pattern
  #
  def pkgname_to_pattern(pkgnames)
    fullname_to_pattern(pkgnames)
  end

  # Convert *portnames* to search pattern for the `make search` command.
  #
  # @param portnames [String|Enumerable] the *portname* or *portnames* to be
  #   turned into search pattern,
  # @return [String] the resultant pattern
  # @see #strings_to_pattern
  #
  def portname_to_pattern(portnames)
    version_pattern = '[a-zA-Z0-9][a-zA-Z0-9\\.,_]*'
    "^#{strings_to_pattern(portnames)}-#{version_pattern}$"
  end

  # Convert *portorigins*, *pkgnames* or *portnames* to search pattern for the
  # `make search` command.
  #
  # What the function exactly does depends on `key`, that is for `:pkgname` it
  # does `pkgname_to_pattern(s)`, for `:portname` -> `portname_to_pattern(s)`
  # and so on.
  #
  # @param key [Symbol] decides how to process `s`, possible values are
  #   `:pkgname`, `:portname`, `:portorigin`. For other values, the function
  #   returns result of `fullname_to_pattern(s)`.
  # @param s [String|Enumerable] a string or a sequence of strings to be turned
  #   into search pattern,
  # @return [String] the resultant search pattern
  def mk_search_pattern(key, s)
    case key
    when :pkgname
      pkgname_to_pattern(s)
    when :portname
      portname_to_pattern(s)
    when :portorigin
      portorigin_to_pattern(s)
    else
      fullname_to_pattern(s)
    end
  end

  # Path to BSD ports source tree.
  # @note you may set `ENV['PORTSDIR']` to override defaults.
  # @return [String] `/usr/pkgsrc` on NetBSD, `/usr/ports` on other systems or
  #   the value defined by `ENV['PORTSDIR']`.
  #
  def portsdir
    unless dir = ENV['PORTSDIR']
      os = Facter.value(:operatingsystem)
      dir = (os == "NetBSD") ? '/usr/pkgsrc' : '/usr/ports'
    end
    dir
  end

  # Path to ports DB directory, defaults to `/var/db/ports`.
  # @note You may set `ENV['PORT_DBDIR']` to override defaults.
  # @return [String] `/var/db/ports`, or the value defined by `ENV['PORT_DBDIR'].
  #
  def port_dbdir
    unless dir = ENV['PORT_DBDIR']
      dir = '/var/db/ports'
    end
    dir
  end

  # Return standard names of option files for a port.
  #
  # When compiling a port, its Makefile may read build options from a set of
  # files. There is a convention to look for options in a predefined set of
  # options files whose names are derived from *portname* and *portorigin*. Up
  # to 4 option files may be read by Makefile (two for *portname* and two for
  # *portorigin*) and options contained in all the files get merged.
  #
  # This method returns for a given *portname* and *portorogin* a list of
  # files that may potentially contain build options for the port. The returned
  # names are in same order as they are read by ports Makefile's. The last file
  # overrides values defined in all previous file, so  it's most significant.
  # 
  # @param portname [String] the *portname* of a port,
  # @param portorigin [String] the *portorigin* for a port
  # @return [Array] an array of absolute paths to option files.
  #
  def options_files(portname, portorigin)
      [
        # keep these in proper order, see /usr/ports/Mk/bsd.options.mk
        portname,                  # OPTIONSFILE,
        portorigin.gsub(/\//,'_'), # OPTIONS_FILE,
      ].flatten.map{|x|
        f = File.join(self.port_dbdir,x,"options")
        [f,"#{f}.local"]
      }.flatten
  end

  # Check whether the pkgng is used by operating system.
  # 
  # This method uses technique proposed by `pkg(8)` man page to detect whether
  # the [pkgng](https://wiki.freebsd.org/pkgng) database is used by local OS.
  # The man page says:
  #
  #     The following script is the safest way to detect if pkg is installed
  #     and activated:
  #
  #         if TMPDIR=/dev/null ASSUME_ALWAYS_YES=1 \
  #             PACKAGESITE=file:///nonexistent \
  #             pkg info -x 'pkg(-devel)?$' >/dev/null 2>&1; then
  #           # pkgng-specifics
  #         else
  #           # pkg_install-specifics
  #         fi
  #
  # The method basically does the same but the commands are invoked from within
  # ruby.
  #
  # @param options [Hash] options to customize method behavior
  # @option options [String] :pkg path to the
  #   [pkg](http://www.freebsd.org/doc/handbook/pkgng-intro.html) command
  # @option options [String] :execpipe handle to a method which executes
  #   external commands in same way as puppet's `execpipe` does, , if not given,
  #   the Puppet::Util::Execution#execpipe is used. 
  # @return [Boolean] `true` if the pkgng is active or `false` otherwise.
  #
  def pkgng_active?(options = {})
    return @pkgng_active unless @pkgng_active.nil?

    pkg = options[:pkg] || (respond_to?(:command) ? command(:pkg) : nil)
    # Detect whether the OS uses old pkg or the new pkgng.
    @pkgng_active = false
    if pkg and FileTest.file?(pkg) and FileTest.executable?(pkg)
      ::Puppet.debug "'#{pkg}' command found, checking whether pkgng is active"
      env = { 'TMPDIR' => '/dev/null', 'ASSUME_ALWAYS_YES' => '1',
              'PACKAGESITE' => 'file:///nonexistent' }
      Puppet::Util.withenv(env) do 
        begin
          # this is technique proposed by pkg(8) man page,
          cmd = [pkg,'info','-x',"'pkg(-devel)?$'",'>/dev/null', '2>&1']
          execpipe = options[:execpipe] || Puppet::Util::Execution.method(:execpipe)
          execpipe.call(cmd) { |pipe| pipe.each_line {} } # just ignore
          @pkgng_active = true
        rescue Puppet::ExecutionFailure
        # nothing
        end
      end
    else
      ::Puppet.debug "'pkg' command not found"
    end
    ::Puppet.debug "pkgng is #{@pkgng_active ? '' : 'in'}active on this system"
    @pkgng_active
  end
end
end
