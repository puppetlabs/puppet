require 'puppet/util'
module Puppet::Util::RDoc
  module_function

  # launch a rdoc documenation process
  # with the files/dir passed in +files+
  def rdoc(outputdir, files, charset = nil)

    # then rdoc
    require 'rdoc/rdoc'
    require 'rdoc/options'

    # load our parser
    require 'puppet/util/rdoc/parser'

    r = RDoc::RDoc.new

    # specify our own format & where to output
    options = [ "--fmt", "puppet",
                "--quiet",
                "--exclude", "/modules/[^/]*/spec/.*$",
                "--exclude", "/modules/[^/]*/files/.*$",
                "--exclude", "/modules/[^/]*/tests/.*$",
                "--exclude", "/modules/[^/]*/templates/.*$",
                "--op", outputdir ]

    options << "--force-update"
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
    raise "RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638"
  end

  # Outputs to the console the documentation
  # of a manifest
  def output(file, ast)
    raise "RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638"
  end

  def output_astnode_doc(ast)
    raise "RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638"
  end

  def output_resource_doc(code)
    raise "RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638"
  end
end
