require 'puppet/parser/ast'

# The receiver of `import(file)` calls; once per imported file, or nil if imports are ignored
#
# Transforms a Pops::Model to classic Puppet AST.
# TODO: Documentation is currently skipped completely (it is only used for Rdoc)
#
class Puppet::Pops::Model::AstTransformer
  AST = Puppet::Parser::AST
  Model = Puppet::Pops::Model

  attr_reader :importer
  def initialize(source_file = "unknown-file", importer=nil)
    @@transform_visitor ||= Puppet::Pops::Visitor.new(nil,"transform",0,0)
    @@query_transform_visitor ||= Puppet::Pops::Visitor.new(nil,"query",0,0)
    @@hostname_transform_visitor ||= Puppet::Pops::Visitor.new(nil,"hostname",0,0)
    @importer = importer
    @source_file = source_file
  end

  # Initialize klass from o (location) and hash (options to created instance).
  # The object o is used to compute a source location. It may be nil. Source position is merged into
  # the given options (non surgically). If o is non-nil, the first found source position going up
  # the containment hierarchy is set. I.e. callers should pass nil if a source position is not wanted
  # or known to be unobtainable for the object.
  #
  # @param o [Object, nil] object from which source position / location is obtained, may be nil
  # @param klass [Class<Puppet::Parser::AST>] the ast class to create an instance of
  # @param hash [Hash] hash with options for the class to create
  #
  def ast(o, klass, hash={})
    # create and pass hash with file and line information
    # PUP-3274 - still needed since hostname transformation requires AST::HostName, and AST::Regexp
    klass.new(merge_location(hash, o))
  end

  # THIS IS AN EXPENSIVE OPERATION
  # The 3x AST requires line, pos etc. to be recorded directly in the AST nodes and this information
  # must be computed.
  # (Newer implementation only computes the information that is actually needed; typically when raising an
  # exception).
  #
  def merge_location(hash, o)
    if o
      pos = {}
      locator = o.locator
      offset = o.is_a?(Model::Program) ? 0 : o.offset
      pos[:line] = locator.line_for_offset(offset)
      pos[:pos]  = locator.pos_on_line(offset)
      pos[:file] = locator.file
      if nil_or_empty?(pos[:file]) && !nil_or_empty?(@source_file)
        pos[:file] = @source_file
      end
      hash = hash.merge(pos)
    end
    hash
  end

  # Transforms pops expressions into AST 3.1 statements/expressions
  def transform(o)
    begin
    @@transform_visitor.visit_this_0(self,o)
    rescue StandardError => e
      loc_data = {}
      merge_location(loc_data, o)
      raise Puppet::ParseError.new(_("Error while transforming to Puppet 3 AST: %{message}") % { message: e.message },
        loc_data[:file], loc_data[:line], loc_data[:pos], e)
    end
  end

  # Transforms pops expressions into AST 3.1 query expressions
  def query(o)
    @@query_transform_visitor.visit_this_0(self, o)
  end

  # Transforms pops expressions into AST 3.1 hostnames
  def hostname(o)
    @@hostname_transform_visitor.visit_this_0(self, o)
  end


  # Ensures transformation fails if a 3.1 non supported object is encountered in a query expression
  #
  def query_Object(o)
    raise _("Not a valid expression in a collection query: %{class_name}") % { class_name: o.class.name }
  end

  # Transforms Array of host matching expressions into a (Ruby) array of AST::HostName
  def hostname_Array(o)
    o.collect {|x| ast x, AST::HostName, :value => hostname(x) }
  end

  def hostname_LiteralValue(o)
    return o.value
  end

  def hostname_QualifiedName(o)
    return o.value
  end

  def hostname_LiteralNumber(o)
    transform(o) # Number to string with correct radix
  end

  def hostname_LiteralDefault(o)
    return 'default'
  end

  def hostname_LiteralRegularExpression(o)
    ast o, AST::Regex, :value => o.value
  end

  def hostname_Object(o)
    raise _("Illegal expression - unacceptable as a node name")
  end

  def transform_Object(o)
    raise _("Unacceptable transform - found an Object without a rule: %{klass}") % { klass: o.class }
  end

  # Nil, nop
  # Bee bopp a luh-lah, a bop bop boom.
  #
  def is_nop?(o)
    o.nil? || o.is_a?(Model::Nop)
  end

  def nil_or_empty?(x)
    x.nil? || x == ''
  end
end
