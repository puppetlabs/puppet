require 'puppet/util'
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

    if Puppet.features.rdoc1?
      RDoc::RDoc::GENERATORS["puppet"] = RDoc::RDoc::Generator.new(
          "puppet/util/rdoc/generators/puppet_generator.rb",
          :PuppetGenerator,
          "puppet"
        )
    end

    # specify our own format & where to output
    options = [ "--fmt", "puppet",
                "--quiet",
                "--exclude", "/modules/[^/]*/spec/.*$",
                "--exclude", "/modules/[^/]*/files/.*$",
                "--exclude", "/modules/[^/]*/tests/.*$",
                "--exclude", "/modules/[^/]*/templates/.*$",
                "--op", outputdir ]

    if !Puppet.features.rdoc1? || ::Options::OptionList.options.any? { |o| o[0] == "--force-update" } # Options is a root object in the rdoc1 namespace...
      options << "--force-update"
    end
    options += [ "--charset", charset] if charset
    # Rdoc root default is Dir.pwd, but the win32-dir gem monkey patchs Dir.pwd
    # replacing Ruby's normal / with \.  When RDoc generates relative paths it
    # uses relative_path_from that will generate errors when the slashes don't
    # properly match.  This is a workaround for that issue.
    if Puppet.features.microsoft_windows? && RDoc::VERSION !~ /^[0-3]\./
      options += [ "--root", Dir.pwd.gsub(/\\/, '/')]
    end
    options += files

    # launch the documentation process
    r.document(options)
  end

  # launch an output to console manifest doc
  def manifestdoc(files)
    Puppet[:ignoreimport] = true
    files.select { |f| FileTest.file?(f) }.each do |f|
      parser = Puppet::Parser::Parser.new(Puppet.lookup(:current_environment))
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
