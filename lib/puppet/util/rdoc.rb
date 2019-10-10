require 'puppet/util'
module Puppet::Util::RDoc
  module_function

  # launch a rdoc documentation process
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
    # Rdoc root default is Dir.pwd, but the win32-dir gem monkey patches Dir.pwd
    # replacing Ruby's normal / with \.  When RDoc generates relative paths it
    # uses relative_path_from that will generate errors when the slashes don't
    # properly match.  This is a workaround for that issue.
    if Puppet::Util::Platform.windows? && RDoc::VERSION !~ /^[0-3]\./
<<<<<<< HEAD
      options += [ "--root", Dir.pwd.gsub(/\\/, '/')]
=======
      options += [ "--root", Dir.pwd.tr('\\', '/')]
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
    end
    options += files

    # launch the documentation process
    r.document(options)
  end

  # launch an output to console manifest doc
  def manifestdoc(files)
    raise _("RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638")
  end

  # Outputs to the console the documentation
  # of a manifest
  def output(file, ast)
    raise _("RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638")
  end

  def output_astnode_doc(ast)
    raise _("RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638")
  end

  def output_resource_doc(code)
    raise _("RDOC SUPPORT FOR MANIFEST HAS BEEN REMOVED - See PUP-3638")
  end
end
