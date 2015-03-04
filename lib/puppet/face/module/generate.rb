Puppet::Face.define(:module, '1.0.0') do
  action(:generate) do
    summary "Generate boilerplate for a new module."
    description <<-EOT
      Generates boilerplate for a new module by creating the directory
      structure and files recommended for the Puppet community's best practices.

      A module may need additional directories beyond this boilerplate
      if it provides plugins, files, or templates.
    EOT

    returns "Array of Pathname objects representing paths of generated files."

    examples <<-EOT
      Generate a new module in the current directory:

      $ puppet module generate puppetlabs-ssh
      We need to create a metadata.json file for this module.  Please answer the
      following questions; if the question is not applicable to this module, feel free
      to leave it blank.

      Puppet uses Semantic Versioning (semver.org) to version modules.
      What version is this module?  [0.1.0]
      -->

      Who wrote this module?  [puppetlabs]
      -->

      What license does this module code fall under?  [Apache-2.0]
      -->

      How would you describe this module in a single sentence?
      -->

      Where is this module's source code repository?
      -->

      Where can others go to learn more about this module?
      -->

      Where can others go to file issues about this module?
      -->

      ----------------------------------------
      {
        "name": "puppetlabs-ssh",
        "version": "0.1.0",
        "author": "puppetlabs",
        "summary": null,
        "license": "Apache-2.0",
        "source": "",
        "project_page": null,
        "issues_url": null,
        "dependencies": [
          {
            "name": "puppetlabs-stdlib",
            "version_requirement": ">= 1.0.0"
          }
        ]
      }
      ----------------------------------------

      About to generate this metadata; continue? [n/Y]
      -->

      Notice: Generating module at /Users/username/Projects/puppet/puppetlabs-ssh...
      Notice: Populating ERB templates...
      Finished; module generated in puppetlabs-ssh.
      puppetlabs-ssh/manifests
      puppetlabs-ssh/manifests/init.pp
      puppetlabs-ssh/metadata.json
      puppetlabs-ssh/README.md
      puppetlabs-ssh/spec
      puppetlabs-ssh/spec/spec_helper.rb
      puppetlabs-ssh/tests
      puppetlabs-ssh/tests/init.pp
    EOT

    option "--skip-interview" do
      summary "Bypass the interactive metadata interview"
      description <<-EOT
        Do not attempt to perform a metadata interview.  Primarily useful for automatic
        execution of `puppet module generate`.
      EOT
    end

    arguments "<name>"

    when_invoked do |name, options|
      # Since we only want to interview if it's being rendered to the console
      # (i.e. when invoked with `puppet module generate`), we can't do any work
      # here in the when_invoked block. The result of this block is then
      # passed to each renderer, which will handle it appropriately; by
      # returning a simple message like this, every renderer will simply output
      # the string.
      # Our `when_rendering :console` handler will ignore this value and
      # actually generate the module.
      #
      # All this is necessary because it is not possible at this point in time
      # to know what the destination of the output is.
      "This format is not supported by this action."
    end

    when_rendering :console do |_, name, options|
      Puppet::ModuleTool.set_option_defaults options

      begin
        # A default dependency for all newly generated modules is being
        # introduced as a substitute for the comments we used to include in the
        # previous module data specifications. While introducing a default
        # dependency is less than perfectly desirable, the cost is low, and the
        # syntax is obtuse enough to justify its inclusion.
        metadata = Puppet::ModuleTool::Metadata.new.update(
          'name' => name,
          'version' => '0.1.0',
          'dependencies' => [
            { 'name' => 'puppetlabs-stdlib', 'version_requirement' => '>= 1.0.0' }
          ]
        )
      rescue ArgumentError
        msg = "Could not generate directory #{name.inspect}, you must specify a dash-separated username and module name."
        raise ArgumentError, msg, $!.backtrace
      end

      dest = Puppet::ModuleTool::Generate.destination(metadata)
      result = Puppet::ModuleTool::Generate.generate(metadata, options[:skip_interview])

      path = dest.relative_path_from(Pathname.pwd)
      puts "Finished; module generated in #{path}."
      result.join("\n")
    end
  end
end

module Puppet::ModuleTool::Generate
  module_function

  def generate(metadata, skip_interview = false)
    interview(metadata) unless skip_interview
    destination = duplicate_skeleton(metadata)
    all_files = destination.basename + '**/*'

    return Dir[all_files.to_s]
  end

  def interview(metadata)
    puts "We need to create a metadata.json file for this module.  Please answer the"
    puts "following questions; if the question is not applicable to this module, feel free"
    puts "to leave it blank."

    begin
      puts
      puts "Puppet uses Semantic Versioning (semver.org) to version modules."
      puts "What version is this module?  [#{metadata.version}]"
      metadata.update 'version' => user_input(metadata.version)
    rescue
      Puppet.err "We're sorry, we could not parse that as a Semantic Version."
      retry
    end

    puts
    puts "Who wrote this module?  [#{metadata.author}]"
    metadata.update 'author' => user_input(metadata.author)

    puts
    puts "What license does this module code fall under?  [#{metadata.license}]"
    metadata.update 'license' => user_input(metadata.license)

    puts
    puts "How would you describe this module in a single sentence?"
    metadata.update 'summary' => user_input(metadata.summary)

    puts
    puts "Where is this module's source code repository?"
    metadata.update 'source' => user_input(metadata.source)

    puts
    puts "Where can others go to learn more about this module?#{ metadata.project_page && "  [#{metadata.project_page}]" }"
    metadata.update 'project_page' => user_input(metadata.project_page)

    puts
    puts "Where can others go to file issues about this module?#{ metadata.issues_url && "  [#{metadata.issues_url}]" }"
    metadata.update 'issues_url' => user_input(metadata.issues_url)

    puts
    puts '-' * 40
    puts metadata.to_json
    puts '-' * 40
    puts
    puts "About to generate this metadata; continue? [n/Y]"

    if user_input('Y') !~ /^y(es)?$/i
      puts "Aborting..."
      exit 0
    end
  end

  def user_input(default=nil)
    print '--> '
    input = STDIN.gets.chomp.strip
    input = default if input == ''
    return input
  end

  def destination(metadata)
    return @dest if defined? @dest
    @dest = Pathname.pwd + metadata.name
    raise ArgumentError, "#{@dest} already exists." if @dest.exist?
    return @dest
  end

  def duplicate_skeleton(metadata)
    dest = destination(metadata)

    puts
    Puppet.notice "Generating module at #{dest}..."
    FileUtils.cp_r skeleton_path, dest

    populate_templates(metadata, dest)
    return dest
  end

  def populate_templates(metadata, destination)
    Puppet.notice "Populating templates..."

    formatters = {
      :erb      => proc { |data, ctx| ERB.new(data).result(ctx) },
      :template => proc { |data, _| data },
    }

    formatters.each do |type, block|
      templates = destination + "**/*.#{type}"

      Dir.glob(templates.to_s, File::FNM_DOTMATCH).each do |erb|
        path = Pathname.new(erb)
        content = block[path.read, binding]

        target = path.parent + path.basename(".#{type}")
        target.open('w') { |f| f.write(content) }
        path.unlink
      end
    end
  end

  def skeleton_path
    return @path if defined? @path
    path = Pathname(Puppet.settings[:module_skeleton_dir])
    path = Pathname(__FILE__).dirname + '../../module_tool/skeleton/templates/generator' unless path.directory?
    @path = path
  end
end
