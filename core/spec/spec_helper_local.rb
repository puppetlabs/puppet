require 'json'

# various spec tests now use json schema validation
# the json-schema gem doesn't support windows
if not Puppet.features.microsoft_windows?
  require 'json'
  require 'json-schema'

  JSON_META_SCHEMA = JSON.parse(File.read('spec/../api/schemas/json-meta-schema.json'))

  # FACTS_SCHEMA is shared across two spec files so promote constant to here
  FACTS_SCHEMA = JSON.parse(File.read('spec/../api/schemas/facts.json'))
end

module PuppetSpec
  FIXTURE_DIR = File.expand_path('spec/fixtures')
end
