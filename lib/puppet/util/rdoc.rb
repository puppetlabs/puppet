
module Puppet::Util::RDoc

  module_function

  # launch a rdoc documenation process
  # with the files/dir passed in +files+
  def rdoc(outputdir, files, charset = nil)
      Puppet[:ignoreimport] = true

      # then rdoc
      require 'rdoc/rdoc'
      require 'rdoc/options'

      # load our parser
      require 'puppet/util/rdoc/parser'

      r = RDoc::RDoc.new

      RDoc::RDoc::GENERATORS["puppet"] = RDoc::RDoc::Generator.new(
          "puppet/util/rdoc/generators/puppet_generator.rb",
          "PuppetGenerator".intern,
          "puppet")

      # specify our own format & where to output
      options = [ "--fmt", "puppet",
        "--quiet",
        "--exclude", "/modules/[^/]*/files/.*\.pp$",
        "--op", outputdir ]

      options << "--force-update" if Options::OptionList.options.any? { |o| o[0] == "--force-update" }
      options += [ "--charset", charset] if charset
      options += files
      #TODO dedup file paths (not strict duplication sense, parents, children, etc

      # launch the documentation process
      r.document(options)
  rescue RDoc::RDocError => e
      raise Puppet::ParseError.new("RDoc error #{e}")
  end

  # launch a output to console manifest doc
  def manifestdoc(files)
    Puppet[:ignoreimport] = true
    files.select { |f| FileTest.file?(f) }.each do |f|
      parser = Puppet::Parser::Parser.new(Puppet::Node::Environment.new(Puppet[:environment]))
      parser.file = f
      ast = parser.parse
      output(f, ast)
    end
  end

  # Ouputs to the console the documentation
  # of a manifest
  def output(file, ast)
    astobj = []
    ast.instantiate('').each do |resource_type|
      astobj << resource_type if resource_type.file == file
    end

    astobj.sort! {|a,b| a.line <=> b.line }.each do |k|
      output_astnode_doc(k)
    end
  end

  def output_astnode_doc(ast)
    puts ast.doc if !ast.doc.nil? and !ast.doc.empty?
    if Puppet.settings[:document_all]
      # scan each underlying resources to produce documentation
      code = ast.code.children if ast.code.is_a?(Puppet::Parser::AST::ASTArray)
      code ||= ast.code
      output_resource_doc(code) unless code.nil?
    end
  end

  def output_resource_doc(code)
    code.sort { |a,b| a.line <=> b.line }.each do |stmt|
      output_resource_doc(stmt.children) if stmt.is_a?(Puppet::Parser::AST::ASTArray)

      if stmt.is_a?(Puppet::Parser::AST::Resource)
        puts stmt.doc if !stmt.doc.nil? and !stmt.doc.empty?
      end
    end
  end

end
