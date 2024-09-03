require 'tempfile'

OUTPUT_DIR = 'references'
MANDIR = File.join(OUTPUT_DIR, 'man')
TYPES_DIR = File.join(OUTPUT_DIR, 'types')

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
TYPES_OVERVIEW_ERB = File.join(__dir__, 'references/types/overview.erb')
TYPES_OVERVIEW_MD  = File.join(TYPES_DIR, 'overview.md')
UNIFIED_TYPE_ERB = File.join(__dir__, 'references/unified_type.erb')
UNIFIED_TYPE_MD  = File.join(OUTPUT_DIR, 'type.md')
SINGLE_TYPE_ERB  = File.join(__dir__, 'references/types/single_type.erb')

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

# Render type information for the specified resource type
# Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/type.rb#L87-L112
def render_resource_type(name, this_type)
  sorted_attribute_list = this_type['attributes'].keys.sort {|a,b|
    # Float namevar(s) to the top and ensure after
    # followed by the others in sort order
    if this_type['attributes'][a]['namevar']
      -1
    elsif this_type['attributes'][b]['namevar']
      1
    elsif a == 'ensure'
      -1
    elsif b == 'ensure'
      1
    else
      a <=> b
    end
  }

  variables = {
    name: name,
    this_type: this_type,
    sorted_attribute_list: sorted_attribute_list,
    sorted_feature_list: this_type['features'].keys.sort,
    longest_attribute_name: sorted_attribute_list.collect{|attr| attr.length}.max
  }
  erb = File.join(__dir__, 'references/types/type.erb')
  render_erb(erb, variables)
end

# Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/type_strings.rb#L19-L99
def extract_resource_types(strings_data)
  strings_data['resource_types'].reduce(Hash.new) do |memo, type|
    memo[ type['name'] ] = {
      'description' => type['docstring']['text'],
      'features' => (type['features'] || []).reduce(Hash.new) {|memo, feature|
        memo[feature['name']] = feature['description']
        memo
      },
      'providers' => strings_data['providers'].select {|provider|
        provider['type_name'] == type['name']
      }.reduce(Hash.new) {|memo, provider|
        description = provider['docstring']['text']
        if provider['commands'] || provider['confines'] || provider['defaults']
          description = description + "\n"
        end
        if provider['commands']
          description = description + "\n* Required binaries: `#{provider['commands'].values.sort.join('`, `')}`"
        end
        if provider['confines']
          description = description + "\n* Confined to: `#{provider['confines'].map{|fact,val| "#{fact} == #{val}"}.join('`, `')}`"
        end
        if provider['defaults']
          description = description + "\n* Default for: `#{provider['defaults'].map{|fact,val| "#{fact} == #{val}"}.join('`, `')}`"
        end
        if provider['features']
          description = description + "\n* Supported features: `#{provider['features'].sort.join('`, `')}`"
        end
        memo[provider['name']] = {
          'features' => (provider['features'] || []),
          'description' => description
        }
        memo
      },
      'attributes' => (type['parameters'] || []).reduce(Hash.new) {|memo, attribute|
        description = attribute['description'] || ''
        if attribute['default']
          description = description + "\n\nDefault: `#{attribute['default']}`"
        end
        if attribute['values']
          description = description + "\n\nAllowed values:\n\n" + attribute['values'].map{|val| "* `#{val}`"}.join("\n")
        end
        memo[attribute['name']] = {
          'description' => description,
          'kind' => 'parameter',
          'namevar' => attribute['isnamevar'] ? true : false,
          'required_features' => attribute['required_features'],
        }
        memo
      }.merge( (type['properties'] || []).reduce(Hash.new) {|memo, attribute|
          description = attribute['description'] || ''
          if attribute['default']
            description = description + "\n\nDefault: `#{attribute['default']}`"
          end
          if attribute['values']
            description = description + "\n\nAllowed values:\n\n" + attribute['values'].map{|val| "* `#{val}`"}.join("\n")
          end
          memo[attribute['name']] = {
            'description' => description,
            'kind' => 'property',
            'namevar' => false,
            'required_features' => attribute['required_features'],
          }
          memo
        }).merge( (type['checks'] || []).reduce(Hash.new) {|memo, attribute|
            description = attribute['description'] || ''
            if attribute['default']
              description = description + "\n\nDefault: `#{attribute['default']}`"
            end
            if attribute['values']
              description = description + "\n\nAllowed values:\n\n" + attribute['values'].map{|val| "* `#{val}`"}.join("\n")
            end
            memo[attribute['name']] = {
              'description' => description,
              'kind' => 'check',
              'namevar' => false,
              'required_features' => attribute['required_features'],
            }
            memo
          })
    }
    memo
  end
end

# Extract type documentation from the current version of puppet. Based on
# https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/type.rb#L52
#
# REMIND This is kind of convoluted and means we're using two completely different
# code paths to generate the overview and unified page of types.
def unified_page_resource_types
  type_json = %x{ruby #{File.join(__dir__, 'references/get_typedocs.rb')}}
  type_data = JSON.load(type_json)
  type_data.keys.sort.map do |name|
    render_resource_type(name, type_data[name])
  end
end

namespace :references do
  desc "Generate configuration reference"
  task :configuration do
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

  desc "Generate resource type references"
  task :type do
    FileUtils.mkdir_p(TYPES_DIR)

    # Locate puppet-strings
    begin
      require 'puppet-strings'
      require 'puppet-strings/version'
    rescue LoadError
      abort("Run `bundle config set with documentation` and `bundle update` to install the `puppet-strings` gem.")
    end

    sha = %x{git rev-parse HEAD}.chomp
    now = Time.now

    # Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/strings.rb#L25-L26
    Tempfile.create do |tmpfile|
      puts "Running puppet strings #{PuppetStrings::VERSION}"
      PuppetStrings.generate(['lib/puppet/type/*.rb'], json: true, path: tmpfile.path)
      strings_data = JSON.load_file(tmpfile.path)

      # convert strings output to data the overview ERB template expects
      type_data = extract_resource_types(strings_data)

      # Generate overview.md
      # Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/type.rb#L40-L47
      types = type_data.keys.reject do |type|
        type == 'component' || type == 'whit'
      end

      variables = {
        title: 'Resource types overview',
        sha: sha,
        now: now,
        types: types
      }

      # Render overview page
      content = render_erb(TYPES_OVERVIEW_ERB, variables)
      File.write(TYPES_OVERVIEW_MD, content)
      puts "Generated #{TYPES_OVERVIEW_MD}"

      # Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/type.rb#L55-L70
      # unified page of types
      variables = {
        title: 'Resource Type Reference (Single-Page)',
        sha: sha,
        now: now,
        types: unified_page_resource_types
      }

      content = render_erb(UNIFIED_TYPE_ERB, variables)
      File.write(UNIFIED_TYPE_MD, content)
      puts "Generated #{UNIFIED_TYPE_MD}"

      # Based on https://github.com/puppetlabs/puppet-docs/blob/1a13be3fc6981baa8a96ff832ab090abc986830e/lib/puppet_references/puppet/type.rb#L78-L85
      # one type per page
      types.each do |type|
        variables = {
          title: "Resource Type: #{type}",
          type: type,
          sha: sha,
          now: now,
          canonical: "/puppet/latest/types/#{type}.html",
          body: render_resource_type(type, type_data[type])
        }

        content = render_erb(SINGLE_TYPE_ERB, variables)
        output = File.join(TYPES_DIR, "#{type}.md")
        File.write(output, content)
        puts "Generated #{output}"
      end
    end
  end

  desc "Generate all reference documentation"
  task :all do
    %w[configuration function report metaparameter man type].each do |ref|
      Rake::Task["references:#{ref}"].invoke
    end
  end
end
