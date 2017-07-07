# This module should be included when a class can be serialized to yaml and
# needs to handle the deserialization from Psych with more control. Psych normally
# pokes values directly into an instance using `instance_variable_set` which completely
# bypasses encapsulation.
#
# The class that includes this module must implement an instance method `initialize_from_hash`
# that is given a hash with attribute to value mappings.
#
module Puppet::Util::PsychSupport
  # This method is called from the Psych Yaml deserializer when it encounters a tag
  # in the form !ruby/object:<class name>.
  #
  def init_with(psych_coder)
    # The PsychCoder has a hashmap of instance variable name (sans the @ symbol) to values
    # to set, and can thus directly be fed to initialize_from_hash.
    #
    initialize_from_hash(psych_coder.map)
  end

  # This method is called from the Psych Yaml serializer
  # The serializer will call this method to create a hash that will be serialized to YAML.
  # Instead of using the object itself during the mapping process we use what is
  # returned by calling `to_data_hash` on the object itself since some of the
  # objects we manage have asymmetrical serialization and deserialization.
  #
  def encode_with(psych_encoder)
    tag = Psych.dump_tags[self.class] || "!ruby/object:#{self.class.name}"
    psych_encoder.represent_map(tag, to_data_hash)
  end
end
