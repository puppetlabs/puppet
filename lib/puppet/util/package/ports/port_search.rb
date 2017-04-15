require 'puppet/util/package'

module Puppet::Util::Package::Ports

# Utilities for searching through FreeBSD ports INDEX (based on `make search`
# command).
#
# Two methods are useful for mortals: {#search_ports} and {#search_ports_by}.
module PortSearch

  require 'puppet/util/package/ports/functions'
  require 'puppet/util/package/ports/port_record'
  include Functions

  # Search ports by name.
  #
  # This method performs `search_ports_by(:portorigin, ...)` for `names`
  # representing port origins, then `search_ports_by(:pkgname, ...)` and
  # finally `search_ports_by(:portname,...)` for the remaining `names`.
  #
  # **Usage example**:
  #
  #     names = ['apache22-2.2.26', 'ruby19']
  #     search_ports(names) do |name,record|
  #       print "name: #{name}\n" # from the names list
  #       print "portorigin: #{record[:portorigin]}\n"
  #       print "\n"
  #     end
  #
  # @param names [Array] a list of port names, may mix *portorigins*,
  #   *pkgnames* and *portnames*,
  # @param fields [Array] a list of fields to be included in the resultant
  #   records,
  # @param options [Hash] see {#execute_make_search},
  # @yield [String, PortRecord] for each port found in the ports INDEX
  #
  def search_ports(names, fields=PortRecord.default_fields, options={})
    origins = names.select{|name| portorigin?(name)}
    do_search_ports(:portorigin,origins,fields,options,names) do |name,record|
      yield [name,record]
    end
    do_search_ports(:pkgname,names.dup,fields,options,names) do |name,record|
      yield [name,record]
    end
    do_search_ports(:portname,names,fields,options) do |name,record|
      yield [name,record]
    end
  end

  # For internal use
  #
  # @param key [Symbol] search key,
  # @param names [Array] search names,
  # @param fields [Array] fields to be included in search result,
  # @param options [Hash] see {#execute_make_search},
  def do_search_ports(key, names, fields, options, nextnames=nil)
    if nextnames
      search_ports_by(key, names, fields, options) do |name,rec|
        # this portorigin, pkgname and portname are already seen,
        nextnames.delete(rec[:pkgname])
        nextnames.delete(rec[:portname])
        nextnames.delete(rec[:portorigin])
        yield [name,rec]
      end
    else
      search_ports_by(key, names, fields, options) do |name,rec|
        yield [name,rec]
      end
    end
  end
  private :do_search_ports

  # Maximum number of package names provided to `make search` when searching
  # ports. Used by {#search_ports_by}. If there is more names requested by
  # caller, the search will be divided into mutliple stages (max 60 names per
  # stage) to keep commandline of reasonable length at each stage.
  MAKE_SEARCH_MAX_NAMES = 60

  # Search ports by either `:name`, `:pkgname`, `:portname` or `:portorigin`.
  #
  # This method uses `make search` command to search through ports INDEX.
  #
  # **Example**:
  #
  #     search_ports_by(:portname, ['apache22', 'apache24']) do |k,r|
  #       print "#{k}:\n#{r.inspect}\n\n"
  #     end
  #
  # @param key [Symbol] search key, one of `:name`, `:pkgname`, `:portname` or
  #   `:portorigin`.
  # @param values [Array] determines what to find, it is either
  #   sting or list of strings determining the name or names of packages to
  #   lookup for,
  # @param options [Hash] additional options to alter method behavior, see
  #   {#execute_make_search},
  # @yield [String, PortRecord] for each port found by `make search`.
  #
  def search_ports_by(key, values, fields=PortRecord.default_fields, options={})
    key = key.downcase.intern unless key.instance_of?(Symbol)
    search_key = determine_search_key(key)

    delete_key = if fields.include?(key)
      false
    else
      fields << key
      true
    end

    # query in chunks to keep command-line of reasonable length
    values.each_slice(MAKE_SEARCH_MAX_NAMES) do |slice|
      pattern = mk_search_pattern(key,slice)
      execute_make_search(search_key, pattern, fields, options) do |record|
        val = record[key].dup
        record.delete(key) if delete_key
        yield [val, record]
      end
    end
  end

  # Determine search key.
  #
  # The mapping between our search keys and search keys used by `make search`
  # command is not one-to-one. For example, to search ports by `:pkgname` one
  # needs in fact to search ports INDEX by `:name`, that is the command should
  # be like:
  #
  #     make ... search name=... # node "name=..." instead of "pkgname=..."
  #
  #  This method maps our keys to keys that should be used with `make search`.
  #
  #  @param key [Symbol] a key to be mapped
  #  @return [Symbol]
  def determine_search_key(key)
    case key
    when :pkgname, :portname; :name;
    when :portorigin; :path;
    else; key;
    end
  end
  private :determine_search_key

  # Search ports using `"make search"` command.
  #
  # By default, the search returns only existing ports. Ports marked as
  # `'Moved:'` are filtered out from output (see `options` parameter).
  # To include also `'Moved:`' fields in output, set `:moved` option to `true`.
  #
  # @param key [Symbol] search key, see {#make_search_command},
  # @param pattern [String] search pattern, see {#make_search_command},
  # @param fields [Array] fields to be requested, see {#make_search_command},
  # @param options [Hash] additional options to alter method behavior,
  # @option options :execpipe [Method] see {#do_execute_make_search},
  # @option options :make [String] see {#do_execute_make_search},
  # @option options :moved [Boolean] see {PortRecord.parse},
  # @yield [PortRecord] records extracted from the output of `make search`
  #   command.
  #
  def execute_make_search(key, pattern, fields=PortRecord.default_fields, options={})

    # We must validate `key` here; `make search` prints error message when key
    # is wrong but exits with 0 (EXIT_SUCCESS), so we have no error indication
    # from make (we use execpipe which mixes stderr and stdout).
    unless PortRecord.search_keys.include?(key)
      raise ArgumentError, "Invalid search key #{key}"
    end

    search_fields = PortRecord.determine_search_fields(fields,key)
    do_execute_make_search(key,pattern,search_fields,options) do |record|
      # add extra fields requested by user
      record.amend!(fields)
      yield record
    end
  end

  # For internal use. This accepts and returns fields defined by ports
  # documentation (`make search` command) and yields Records.
  #
  # @param key [Symbol] search key, see {#make_search_command},
  # @param pattern [String] search pattern, see {#make_search_command},
  # @param fields [Array] fields to be requested, see {#make_search_command},
  # @param options [Hash] additional options to alter method behavior
  # @option options :execpipe [Method] handle to a method implementing
  #   execpipe; should have same interface as
  #   `Puppet::Util::Execution.execpipe`,
  # @option options :make [String] absolute path to `make` program,
  # @option options :moved [Boolean] see {PortRecord.parse},
  # @yield [PortRecord] records extracted from the output of make search
  #   command.
  def do_execute_make_search(key, pattern, fields, options)
    execpipe = options[:execpipe] || Puppet::Util::Execution.method(:execpipe)
    cmd = make_search_command(key, pattern, fields, options)
    execpipe.call(cmd) do |process|
      each_paragraph_of(process) do |paragraph|
        if record = PortRecord.parse(paragraph, options)
          yield record
        end
      end
    end
  end
  private :do_execute_make_search

  # Construct `make search` command to be executed with execpipe.
  #
  # @param key [Symbol] search key to be used in `#{key}=#{pattern}`
  #   expression of `make search` command; if __key__ is `'name'` for example,
  #   then the resultan search command will be `make ... search name=...`
  # @param pattern [Sting] search pattern to be used in `#{key}=#{pattern}`
  #   expression of `make search` command; if __key__ is `'name'` and
  #   __pattern__ is `'foo'` for example, then the resultant `make search
  #   command` will be `make ... search name=foo ...`,
  # @param fields [Array] fields to be requested; if __fields__ are
  #   `['f1','f2',...]` for example, then the resultant search command will be
  #   `make search ... display=f1,f2,...`,
  # @param options [Hash] additional options to alter methods behavior,
  # @option options :make [String] absolute path to `make` program,
  # @return [Array] the command to be executed.
  #
  def make_search_command(key, pattern, fields, options)
    make = options[:make] ||
      (self.respond_to?(:command) ? command(:make) : 'make')
    args = ['-C', portsdir, 'search', "#{key}='#{pattern}'"]
    fields = fields.join(',') unless fields.is_a?(String)
    args << "display='#{fields}'"
    [make,*args]
  end

  # Yields paragraphs of the input.
  #
  # Paragraps are portions of __input__ text separated by empty lines.
  # 
  # @param input [String] input string to be split into paragraphs,
  # @yield [String] paragraphs extracted from __input__.
  def each_paragraph_of(input)
    paragraph = ''
    has_lines = false
    input.each_line do |line|
      if line =~ /^\s*\n?$/
        yield paragraph if has_lines
        paragraph = ''
        has_lines = false
      else
        paragraph << line
        has_lines = true
      end
    end
    yield paragraph if has_lines
  end
  private :each_paragraph_of
end
end
