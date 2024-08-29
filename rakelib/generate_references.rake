require 'tempfile'

OUTPUT_DIR = 'references'
CONFIGURATION_ERB = File.join(__dir__, 'references/configuration.erb')
CONFIGURATION_MD  = File.join(OUTPUT_DIR, 'configuration.md')

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
end
