# This module should be included when a class can be serialized to yaml and
# needs to handle the deserialization from Psych with more control. Psych normall
# pokes values directly into an instance using `instance_variable_set` which completely
# bypasses encapsulation.
#
# The class that includes this module must implement an instance method `initialize_from_hash`
# that is given a hash with attribute to value mappings.
#
module Puppet::Util::PsychSupport
  # This method is called from the Psych Yaml deserializer.
  # The serializer calls this instead of doing the initialization itself using
  # `instance_variable_set`. The Status class requires this because it serializes its TagSet
  # as an `Array` in order to optimize the size of the serialized result.
  # When this array is later deserialized it must be reincarnated as a TagSet. The standard
  # Psych way of doing this via poking values into instance variables cannot do this.
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
    tag = Psych.dump_tags[self.class]
    unless tag
      klass = self.class == Object ? nil : self.class.name
      tag   = ['!ruby/object', klass].compact.join(':')
    end
    psych_encoder.represent_map(tag, to_data_hash)
  end
end
