require 'puppet/util/package'

module Puppet::Util::Package::Ports
# Utilities for searching through the database of installed FreeBSD ports
# (based on `portversion` command).
#
# One method is useful for mortals, the {#search_packages} method.
module PkgSearch

  require 'puppet/util/package/ports/functions'
  require 'puppet/util/package/ports/pkg_record'
  include Functions

  # Search installed packages
  #
  # **Usage example 1**:
  #
  #     search_packages do |record|
  #       print "#{record.inspect}\n\n"
  #     end
  #
  # **Usage example 2**:
  #
  #     search_packages(['apache22', 'lang/ruby']) do |name,record|
  #       print "#{name}:\n"
  #       print "#{record.inspect}\n\n"
  #     end
  #
  # @param names [Array|nil] list of package names (may mix portorigins,
  #   pkgnames and portnames); if `nil` - yield all installed packages,
  # @param fields [Array] list of fields to be included in resultant records,
  # @param options additional options
  # @yield [[String,PkgRecord]|PkgRecord] for each found package; the
  #   second form appears at output if `names` were not provided (or were
  #   `nil`).
  #
  #
  def search_packages(names=nil, fields=PkgRecord.default_fields, options={})
    amend = names ? lambda {|r| r[1].amend!(fields)} :
                    lambda {|r| r.amend!(fields)}
    search_fields = PkgRecord.determine_search_fields(fields)
    search_packages_1(names,search_fields,options) do |record|
      amend.call(record)
      yield record
    end
  end

  def search_packages_1(names, fields, options)
    merge = names ? lambda {|r1,r2| r1[1].merge!(r2[1]) } :
                    lambda {|r1,r2| r1.merge!(r2) }
    # sometimes we have to call portversion twice (perform two passes),
    # pass1 and pass2 contain arguments for search_packages_2 for the first
    # and second pass respectivelly
    pass1, pass2 = if fields.include?(:portorigin)
      if (fields & [:pkgname, :portname]).empty?
        [ [ %w{-v -o}, [:portorigin, :portstatus, :portinfo] ], nil ]
      else
        [[ %w{-v -F}, [:pkgname,:portstatus,:portinfo]], [ %w{-Q -o}, [:portorigin] ]]
      end
    else
      [[ %w{-v -F}, [:pkgname, :portstatus, :portinfo] ], nil]
    end
    # find installed packages, retrieve port status (<,=,>) and additional
    # information from portversion command
    records = search_packages_2(names,pass1[0],pass1[1],options)
    if pass2 and not records.empty?
      records2 = search_packages_2(names,pass2[0],pass2[1],options)
      records.zip(records2).each { |r1,r2| merge.call(r1,r2) }
    end
    records.each { |rec | yield rec }
  end
  private :search_packages_1

  def search_packages_2(names,args,keys,options)
    adapt = names ? lambda { |x| [x[0],PkgRecord[keys.zip(x[1])]] } :
                    lambda { |x| PkgRecord[keys.zip(x)] }
    records = []
    portversion_search(names, args) { |x| records << adapt.call(x) }
    records
  end
  private :search_packages_2

  # Maximum number of package names provided to `portversion` when searching
  # installed ports. Used by {#portversion_search}. If there is more names
  # requested by caller, the search will be divided into mutliple stages (max 60
  # names per stage) to  keep commandline of reasonable length at each stage.
  PORTVERSION_MAX_NAMES = 60

  # Search for installed ports.
  #
  # This method calls `portversion` to search through installed ports.
  #
  # The yielded `fields` (see below) are formed as follows:
  #
  # * `fields[0]` - contains the *portname*, *pkgname* or *portorigin*
  #   depending on what was printed by `portversion` (depending on flags in
  #   `args`),
  # * `fields[1]` (optional) - contains the port status, it's a single
  #   character, one of `<`, `=`, `>`, `?`, `!`, `#`
  # * `fields[2]` (optional) - contains additional information about available
  #   update for the package
  #
  # What is particularly yielded by {#portversion_search} dependends on `args`.
  # See [portversion(1)](http://www.freebsd.org/cgi/man.cgi?query=portversion&manpath=ports&sektion=1).
  #
  # Supported `options` are:
  #
  # * :execpipe - custom execpipe method (used to call `portversion`),
  # * options supported by the {#portversion_command} method.
  #
  # @param names [Array|nil] list of packages to search for; if `nil` - show all,
  # @param args [Array] an array of command line flags to `portversion`
  # @param options [Hash] additional options,
  # @yield Array for each found package. If `name` is `nil`: an array of
  #   `fields` (up to 3) returned by `portversion` for each package; if `name`
  #   is not `nil`: a 2-element array in form `[name, fields]` for each package
  #   found by `portversion`, where name is one of the `names` and `fields` are
  #   values printed by `portversion` in consecutive columns (up to 3).
  #
  def portversion_search(names=nil, args=[], options={})
    if names
      names = sort_names_for_portversion(names)
      names.each_slice(PORTVERSION_MAX_NAMES) do |slice|
        portversion_search_1(slice, args, options) { |xfields| yield xfields }
      end
    else
      execute_portversion(args, options) { |fields| yield fields }
    end
  end

  def portversion_search_1(slice, args, options)
    results = []
    execute_portversion(args + slice, options) {|fields| results << fields}
    # we expect one valid output line for one input name in slice, if
    # numbers doesn't agree, then something went wrong
    if (slice.length == results.length)
      slice.zip(results).each { |pair| yield pair }
    elsif (results.length > 0)
      slice.each do |name|
        # Invoke portversion for each of the failed packages individually
        # (actually for each package from failed slices).
        execute_portversion(args + [name], options) do |fields|
          yield [name, fields]
        end
      end
    end
  end
  private :portversion_search_1

  # For internal use.
  def determine_portversion_key_check(args)
    if args.include?('-f') or args.include?('-F')
      lambda { |s| pkgname?(s) }
    elsif args.include?('-o')
      lambda { |s| portorigin?(s) }
    elsif args.include?('-v')
      lambda { |s| pkgname?(s) }
    else
      lambda { |s| portname?(s) }
    end
  end
  private :determine_portversion_key_check

  def sort_names_for_portversion(names)
    # XXX: portversion (at least 2.4.11) sorts its output by pkgname/portname,
    # so we must do the same with input list to match ones to the others; this
    # is horrible and there are no docs saying that this sorting method is
    # guaranted; for now we just have to live with this uncertainity.
    names.sort{ |a,b|
      a = a.split('/').last if portorigin?(a)
      b = b.split('/').last if portorigin?(b)
      a <=> b
    }
  end

  def execute_portversion(args, options = {})
    key_check = determine_portversion_key_check(args)
    execpipe = options[:execpipe] || Puppet::Util::Execution.method(:execpipe)
    cmd = portversion_command(args, options)
    execpipe.call(cmd) do |process|
      process.each_line do |line|
        fields = line.strip.split(/\s+/,3)
        # portversion sometimes puts garbage to its output; we skip such lines
        if key_check.call(fields.first)
          yield fields
        end
      end
    end
  end

  # Return 'portversion ...' command (as array) to be used with execpipe().
  def portversion_command(args, options)
    portversion = options[:portversion] ||
      (self.respond_to?(:command) ? command(:portversion) : 'portversion')
    [portversion, *(args.flatten)]
  end
end
end
