# Walks the memory dumped into heap.json, and produces a graph of the memory dumped in diff.json
# If a single argument (a hex address to one object) is given, the graph is limited to this object and what references it
# The heap dumps should be in the format produced by Ruby ObjectSpace in Ruby version 2.1.0 or later.
#
# The command produces a .dot file that can be rendered with graphwiz dot into SVG. If a memwalk is performed for all
# objects in the diff.json, the output file name is memwalk.dot. If it is produced for a single address, the name of the
# output file is memwalk-<address>.dot
#
# The dot file can be rendered with something like: dot -Tsvg -omemwalk.svg memwalk.dot
#
desc "Process a diff.json of object ids, and a heap.json of a Ruby 2.1.0 ObjectSpace dump and produce a graph"
task :memwalk, [:id] do |t, args|
  puts "Memwalk"
  puts "Computing for #{args[:id] ? args[:id] : 'all'}"
  @single_id = args[:id] ? args[:id].to_i(16) : nil

  require 'json'
  #require 'debug'

  TYPE = "type".freeze
  ROOT = "root".freeze
  ROOT_UC = "ROOT".freeze
  ADDR = "address".freeze
  NODE = "NODE".freeze
  STRING = "STRING".freeze
  DATA = "DATA".freeze
  HASH = "HASH".freeze
  ARRAY = "ARRAY".freeze
  OBJECT = "OBJECT".freeze
  CLASS = "CLASS".freeze

  allocations = {}
  # An array of integer addresses of the objects to trace bindings for
  diff_index = {}
  puts "Reading data"
  begin
    puts "Reading diff"
    lines = 0;
    File.readlines("diff.json").each do | line |
      lines += 1
      diff = JSON.parse(line)
      case diff[ TYPE ]
      when STRING, DATA, HASH, ARRAY
        # skip the strings
      else
        diff_index[ diff[ ADDR ].to_i(16) ] = diff
      end
    end
    puts "Read #{lines} number of diffs"
  rescue => e
    raise "ERROR READING DIFF at line #{lines} #{e.message[0, 200]}"
  end

  begin
    puts "Reading heap"
    lines = 0
    allocation = nil
    File.readlines("heap.json").each do | line |
      lines += 1
      allocation = JSON.parse(line)
      case allocation[ TYPE ]
      when ROOT_UC
        # Graph for single id must include roots, as it may be a root that holds on to the reference
        # a global variable, thread, etc.
        #
        if @single_id
          allocations[ allocation[ ROOT ] ] = allocation
        end
      when NODE
        # skip the NODE objects - they represent the loaded ruby code
      when STRING
        # skip all strings - they are everywhere
      else
        allocations[ allocation[ ADDR ].to_i(16) ] = allocation
      end
    end
    puts "Read #{lines} number of entries"
  rescue => e
    require 'debug'
    puts "ERROR READING HEAP #{e.message[0, 200]}"
    raise e
  end
  @heap = allocations

  puts "Building reference index"
  # References is an index from a referenced object to an array with addresses to the objects that references it
  @references = Hash.new { |h, k| h[k] = [] }
  REFERENCES = "references".freeze
  allocations.each do |k,v|
    refs = v[ REFERENCES ]
    if refs.is_a?(Array)
      refs.each {|addr| @references[ addr.to_i(16) ] << k }
    end
  end

  @printed = Set.new()

  def print_object(addr, entry)
    # only print each node once
    return unless @printed.add?(addr)
    begin
    if addr.is_a?(String)
      @output.write( "x#{node_name(addr)} [label=\"#{node_label(addr, entry)}\\n#{addr}\"];\n")
    else
      @output.write( "x#{node_name(addr)} [label=\"#{node_label(addr, entry)}\\n#{addr.to_s(16)}\"];\n")
    end
    rescue => e
      require 'debug'
      raise e
    end
  end

  def node_label(addr, entry)
    if entry[ TYPE ] == OBJECT
      class_ref = entry[ "class" ].to_i(16)
      @heap[ class_ref ][ "name" ]
    elsif entry[ TYPE ] == CLASS
      "CLASS #{entry[ "name"]}"
    else
      entry[TYPE]
    end
  end

  def node_name(addr)
    return addr if addr.is_a? String
    addr.to_s(16)
  end

  def print_edge(from_addr, to_addr)
    @output.write("x#{node_name(from_addr)}->x#{node_name(to_addr)};\n")
  end

  def closure_and_edges(diff)
    edges = Set.new()
    walked = Set.new()
    puts "Number of diffs referenced = #{diff.count {|k,_| @references[k].is_a?(Array) && @references[k].size() > 0 }}"
    diff.each {|k,_| walk(k, edges, walked) }
    edges.each {|e| print_edge(*e) }
  end

  def walk(addr, edges, walked)
    if !@heap[ addr ].nil?
      print_object(addr, @heap[addr])

      @references [ addr ].each do |r|
        walk_to_object(addr, r, edges, walked)
      end
    end
  end

  def walk_to_object(to_addr, cursor, edges, walked)
    return unless walked
    # if walked to an object, or everything if a single_id is the target
    if @heap[ cursor ][ TYPE ] == OBJECT || (@single_id && @heap[ cursor ][ TYPE ] == ROOT_UC || @heap[ cursor ][ TYPE ] == CLASS )
      # and the edge is unique
      if edges.add?( [ cursor, to_addr ] )
        # then we may not have visited objects this objects is being referred from
        print_object(cursor, @heap[ cursor ])
        # Do not follow what binds a class
        if @heap[ cursor ][ TYPE ] != CLASS
          @references[ cursor ].each do |r|
            walk_to_object(cursor, r, edges, walked.add?(r))
            walked.delete(r)
          end
        end
      end
    else
      # continue search until Object
      @references[cursor].each do |r|
        walk_to_object(to_addr, r, edges, walked.add?(r))
      end
    end
  end

  def single_closure_and_edges(the_target)
    edges = Set.new()
    walked = Set.new()
    walk(the_target, edges, walked)
    edges.each {|e| print_edge(*e) }
  end

  puts "creating graph"
  if @single_id
    @output = File.open("memwalk-#{@single_id.to_s(16)}.dot", "w")
    @output.write("digraph root {\n")
    single_closure_and_edges(@single_id)
  else
    @output = File.open("memwalk.dot", "w")
    @output.write("digraph root {\n")
    closure_and_edges(diff_index)
  end
  @output.write("}\n")
  @output.close
  puts "done"
end
