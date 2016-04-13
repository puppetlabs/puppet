require_relative 'time_factory'
require_relative 'abstract_writer'
require_relative 'abstract_reader'

module Puppet::Pops
module Serialization

module MsgPack
  # The `Writer` registers an extension for the `ExtSymbol` class instead of `Symbol` to circumvent the fact that
  # the `MessagePack::Packer` will write a `Symbol` as a `String` without consulting registered types.
  class ExtSymbol
    # The symbol is tabulated by the layer above since it's light weight (no duplicates, i.e. unique by identity)
    include Extension::NotTabulated

    attr_reader :symbol
    def initialize(symbol)
      @symbol = symbol
    end
  end

  class Writer < AbstractWriter
    def initialize(io, options = {})
      packer = MessagePack::Packer.new(io, options)
      extension_packer = MessagePack::Packer.new(:io_buffer_size => 256)

      debug_io = options[:debug_io]
      unless debug_io.nil?
        verbose = options[:verbose]
        verbose = false if verbose.nil?
        indent = options[:indent] || 2
        extension_packer = DebugPacker.new(extension_packer, nil, debug_io, indent, verbose)
        packer = DebugPacker.new(packer, extension_packer, debug_io, indent, verbose)
      end

      super(packer, options, extension_packer)

      register_type(Extension::SYMBOL, ExtSymbol) do |o|
        build_payload { |ep| ep.write(o.symbol.to_s) }
      end
    end

    def write(value)
      # Symbol must be wrapped in ExtSymbol to trigger extension
      value = ExtSymbol.new(value) if value.is_a?(Symbol)
      super(value)
    end

    def build_payload
      ep = extension_packer
      ep.clear
      yield(ep)
      ep.to_s
    end
  end

  class Reader < AbstractReader
    def initialize(io, options = {})
      super(MessagePack::Unpacker.new(io, options), MessagePack::Unpacker.new(:io_buffer_size => 256))
    end

    def read_payload(data)
      ep = extension_unpacker
      ep.feed(data)
      yield(ep)
    end
  end

  # The DebugPacker wraps an instance of `MessagePack::Packer` that it dispatches all calls to. It will also
  # produce a Lisp-like output of everything that is packed.
  #
  class DebugPacker
    attr_accessor :nested

    def initialize(packer, ext_debug_packer, debug_io, indent = 2, verbose = false)
      @packer = packer
      @ext_debug_packer = ext_debug_packer
      @debug_io = debug_io
      @type_registry = {}
      @nested = [-1]
      @indent = indent
      @verbose = verbose
    end

    def respond_to_missing?(name, include_private)
      @packer.respond_to?(name, include_private)
    end

    def method_missing(name, *arguments, &block)
      @packer.send(name, *arguments, &block)
    end

    def register_type(type, klass, &block)
      @type_registry[klass] = [type, klass]
      @packer.register_type(type, klass, &block)
    end

    def write(obj)
      ext = @type_registry[obj.class]
      if ext.nil?
        @debug_io << newline << obj.to_json
        @packer.write(obj)
        after_write
      else
        @debug_io << newline << '(extension ' << extension_indicator(ext)
        @nested << -1
        @ext_debug_packer.nested = @nested
        # write will call block on exension which calls back into a DebugPacker
        @packer.write(obj)
        if obj.is_a?(Extension::SequenceStart) && obj.sequence_size > 0
          @nested[@nested.size - 1] = obj.sequence_size
        else
          @nested.pop
          @debug_io << newline << ')'
          after_write
        end
      end
    end
    alias pack write

    def after_write
      last_idx = @nested.size - 1
      @nested[last_idx] -= 1
      nestpop = 0
      while @nested.last == 0
        @nested.pop
        last_idx -= 1
        @nested[last_idx] -= 1
        nestpop += 1
      end
      if nestpop > 0
        @debug_io << newline
        nestpop.times { @debug_io << ')' }
      end
    end

    def write_array_header(n)
      @debug_io << newline << '(array_header ' << n
      @nested << n
      @packer.write_array_header(n)
    end

    def write_map_header(n)
      @debug_io << newline << '(map_header ' << n << ')'
      @nested << n * 2
      @packer.write_map_header(n)
    end

    def write_nil
      @debug_io << newline << 'null'
      @packer.write_nil
      after_write
    end

    def to_s
      @packer.to_s
    end

    private

    def extension_indicator(ext)
      @verbose ? ext[1].name.sub(/^Puppet::Pops::Serialization::\w+::(.+)$/, '\1') : '0x%2.2x' % ext[0]
    end

    def newline
      if @indent == 0
        ' '
      else
        "\n#{' ' * @indent * (@nested.size - 1)}"
      end
    end
  end
end
end
end
