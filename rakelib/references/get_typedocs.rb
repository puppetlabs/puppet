# This script will print the Puppet type docs to stdout in JSON format.

# There are some subtleties that make this a pain to run. Basically: Even if you
# 'require' a specific copy of the Puppet code, the autoloader will grab bits
# and pieces of Puppet code from other copies of Puppet scattered about the Ruby
# load path. This causes a mixture of docs from different versions: although I
# think the version you require will usually win for things that exist in both
# versions, providers or attributes that only exist in one version will leak
# through and you'll get an amalgamation.

# So the only safe thing to do is run this in a completely separate process, and
# ruthlessly control the Ruby load path. We expect that when you're executing
# this code, your $RUBYLIB contains the version of Puppet you want to load, and
# there are no other versions of Puppet available as gems, installed via system
# packages, etc. etc. etc.

require 'json'
require 'puppet'
require 'puppet/util/docs'
extend Puppet::Util::Docs
# We use scrub().


  # The schema of the typedocs object:

  # { :name_of_type => {
  #     :description => 'Markdown fragment: description of type',
  #     :features    => { :feature_name => 'feature description', ... }
  #       # If there are no features, the value of :features will be an empty hash.
  #     :providers   => { # If there are no providers, the value of :providers will be an empty hash.
  #       :name_of_provider => {
  #         :description => 'Markdown fragment: docs for this provider',
  #         :features    => [:feature_name, :other_feature, ...]
  #           # If provider has no features, the value of :features will be an empty array.
  #       },
  #       ...etc...
  #     }
  #     :attributes  => { # Puppet dictates that there will ALWAYS be at least one attribute.
  #       :name_of_attribute => {
  #         :description => 'Markdown fragment: docs for this attribute',
  #         :kind        => (:property || :parameter),
  #         :namevar     => (true || false), # always false if :kind => :property
  #       },
  #       ...etc...
  #     },
  #   },
  #   ...etc...
  # }
typedocs = {}

Puppet::Type.loadall

Puppet::Type.eachtype { |type|
  # List of types to ignore:
  next if type.name == :puppet
  next if type.name == :component
  next if type.name == :whit

  # Initialize the documentation object for this type
  docobject = {
    :description => scrub(type.doc),
    :attributes  => {}
  }

  # Handle features:
  # inject will return empty hash if type.features is empty.
  docobject[:features] = type.features.inject( {} ) { |allfeatures, name|
    allfeatures[name] = scrub( type.provider_feature(name).docs )
    allfeatures
  }

  # Handle providers:
  # inject will return empty hash if type.providers is empty.
  docobject[:providers] = type.providers.inject( {} ) { |allproviders, name|
    allproviders[name] = {
      :description => scrub( type.provider(name).doc ),
      :features    => type.provider(name).features
    }
    allproviders
  }

  # Override several features missing due to bug #18426:
  if type.name == :user
    docobject[:providers][:useradd][:features] << :manages_passwords << :manages_password_age << :libuser
    if docobject[:providers][:openbsd]
      docobject[:providers][:openbsd][:features] << :manages_passwords << :manages_loginclass
    end
  end
  if type.name == :group
    docobject[:providers][:groupadd][:features] << :libuser
  end


  # Handle properties:
  docobject[:attributes].merge!(
    type.validproperties.inject( {} ) { |allproperties, name|
      property = type.propertybyname(name)
      raise "Could not retrieve property #{propertyname} on type #{type.name}" unless property
      description = property.doc
      $stderr.puts "No docs for property #{name} of #{type.name}" unless description and !description.empty?

      allproperties[name] = {
        :description => scrub(description),
        :kind        => :property,
        :namevar     => false # Properties can't be namevars.
      }
      allproperties
    }
  )

  # Handle parameters:
  docobject[:attributes].merge!(
    type.parameters.inject( {} ) { |allparameters, name|
      description = type.paramdoc(name)
      $stderr.puts "No docs for parameter #{name} of #{type.name}" unless description and !description.empty?

      # Strip off the too-huge provider list. The question of what to do about
      # providers is a decision for the formatter, not the fragment collector.
      description = description.split('Available providers are')[0] if name == :provider

      allparameters[name] = {
        :description => scrub(description),
        :kind        => :parameter,
        :namevar     => type.key_attributes.include?(name) # returns a boolean
      }
      allparameters
    }
  )

  # Finally:
  typedocs[type.name] = docobject
}

print JSON.dump(typedocs)
