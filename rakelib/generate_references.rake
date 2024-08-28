require 'tempfile'

OUTPUT_DIR = 'references'
MANDIR = File.join(OUTPUT_DIR, 'man')

CONFIGURATION_ERB = File.join(__dir__, 'references/configuration.erb')
CONFIGURATION_MD  = File.join(OUTPUT_DIR, 'configuration.md')
METAPARAMETER_ERB = File.join(__dir__, 'references/metaparameter.erb')
METAPARAMETER_MD  = File.join(OUTPUT_DIR, 'metaparameter.md')
REPORT_ERB        = File.join(__dir__, 'references/report.erb')
REPORT_MD         = File.join(OUTPUT_DIR, 'report.md')
FUNCTIONS_TEMPLATE_ERB = File.join(__dir__, 'references/functions_template.erb')
FUNCTION_ERB      = File.join(__dir__, 'references/function.erb')
FUNCTION_MD       = File.join(OUTPUT_DIR, 'function.md')
MAN_OVERVIEW_ERB  = File.join(__dir__, 'references/man/overview.erb')
MAN_OVERVIEW_MD   = File.join(MANDIR, "overview.md")
MAN_ERB           = File.join(__dir__, 'references/man.erb')

def render_erb(erb_file, variables)
  # Create a binding so only the variables we specify will be visible
  template_binding = OpenStruct.new(variables).instance_eval {binding}
  ERB.new(File.read(erb_file), trim_mode: '-').result(template_binding)
end

def puppet_doc(reference)
  body = %x{bundle exec puppet doc -r #{reference}}
  # Remove the first H1 with the title, like "# Metaparameter Reference"
  body.sub!(/^# \w+ Reference *$/, '')
  body.chomp
end

# This is adapted from https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/puppet_doc.rb#L22-L36
def generate_reference(reference, erb, body, output)
  sha = %x{git rev-parse HEAD}.chomp
  now = Time.now
  variables = {
    sha: sha,
    now: now,
    body: body
  }
  content = render_erb(erb, variables)
  File.write(output, content)
  puts "Generated #{output}"
end

namespace :references do
  desc "Generate configuration reference"
  task :configuration do
    ENV['PUPPET_REFERENCES_HOSTNAME'] = "(the system's fully qualified hostname)"
    ENV['PUPPET_REFERENCES_DOMAIN'] = "(the system's own domain)"

    body = puppet_doc('configuration')
    generate_reference('configuration', CONFIGURATION_ERB, body, CONFIGURATION_MD)
  end

  desc "Generate metaparameter reference"
  task :metaparameter do
    body = puppet_doc('metaparameter')
    generate_reference('metaparameter', METAPARAMETER_ERB, body, METAPARAMETER_MD)
  end

  desc "Generate report reference"
  task :report do
    body = puppet_doc('report')
    generate_reference('report', REPORT_ERB, body, REPORT_MD)
  end

  desc "Generate function reference"
  task :function do
    # Locate puppet-strings
    begin
      require 'puppet-strings'
      require 'puppet-strings/version'
    rescue LoadError
      abort("Run `bundle config set with documentation` and `bundle update` to install the `puppet-strings` gem.")
    end

    strings_data = {}
    Tempfile.create do |tmpfile|
      puts "Running puppet strings #{PuppetStrings::VERSION}"
      PuppetStrings.generate(['lib/puppet/{functions,parser/functions}/**/*.rb'], json: true, path: tmpfile.path)
      strings_data = JSON.load_file(tmpfile.path)
    end

    # Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/functions.rb#L24-L56
    functions = strings_data['puppet_functions']

    # Deal with the duplicate 3.x and 4.x functions
    # 1. Figure out which functions are duplicated.
    names = functions.map { |func| func['name'] }
    duplicates = names.uniq.select { |name| names.count(name) > 1 }
    # 2. Reject the 3.x version of any dupes.
    functions = functions.reject do |func|
      duplicates.include?(func['name']) && func['type'] != 'ruby4x'
    end

    # renders the list of functions
    body = render_erb(FUNCTIONS_TEMPLATE_ERB, functions: functions)

    # This substitution could potentially make things a bit brittle, but it has to be done because the jump
    # From H2s to H4s is causing issues with the DITA-OT, which sees this as a rule violation. If it
    # Does become an issue, we should return to this and figure out a better way to generate the functions doc.
    body.gsub!(/#####\s(.*?:)/,'**\1**').gsub!(/####\s/,'### ').chomp!

    # renders the preamble and list of functions
    generate_reference('function', FUNCTION_ERB, body, FUNCTION_MD)
  end

  desc "Generate man as markdown references"
  task :man do
    FileUtils.mkdir_p(MANDIR)

    begin
      require 'pandoc-ruby'
    rescue LoadError
      abort("Run `bundle config set with documentation` and `bundle update` to install the `pandoc-ruby` gem.")
    end

    pandoc = %x{which pandoc}.chomp
    unless File.executable?(pandoc)
      abort("Please install the `pandoc` package.")
    end

    sha = %x{git rev-parse HEAD}.chomp
    now = Time.now

    # This is based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/man.rb#L24-L108
    core_apps = %w(
      agent
      apply
      lookup
      module
      resource
    )
    occasional_apps = %w(
      config
      describe
      device
      doc
      epp
      generate
      help
      node
      parser
      plugin
      script
      ssl
    )
    weird_apps = %w(
      catalog
      facts
      filebucket
      report
    )

    variables = {
      sha: sha,
      now: now,
      title: 'Puppet Man Pages',
      core_apps: core_apps,
      occasional_apps: occasional_apps,
      weird_apps: weird_apps
    }

    content = render_erb(MAN_OVERVIEW_ERB, variables)
    File.write(MAN_OVERVIEW_MD, content)
    puts "Generated #{MAN_OVERVIEW_MD}"

    # Generate manpages in roff
    Rake::Task[:gen_manpages].invoke

    # Convert the roff formatted man pages to markdown, based on
    # https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/man.rb#L119-L128
    files = Pathname.glob(File.join(__dir__, '../man/man8/*.8'))
    files.each do |f|
      next if File.basename(f) == "puppet.8"

      app = File.basename(f).delete_prefix('puppet-').delete_suffix(".8")

      body =
        PandocRuby.convert([f], from: :man, to: :markdown)
        .gsub(/#(.*?)\n/, '##\1')
        .gsub(/:\s\s\s\n\n```\{=html\}\n<!--\s-->\n```/, '')
        .gsub(/\n:\s\s\s\s/, '')
        .chomp

      variables = {
        sha: sha,
        now: now,
        title: "Man Page: puppet #{app}",
        canonical: "/puppet/latest/man/#{app}.html",
        body: body
      }

      content = render_erb(MAN_ERB, variables)
      output = File.join(MANDIR, "#{app}.md")
      File.write(output, content)
      puts "Generated #{output}"
    end
  end
end
