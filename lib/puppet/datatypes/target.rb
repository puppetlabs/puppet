Puppet::DataTypes.create_type('Target') do
  interface <<-PUPPET
    attributes => {
      host => String[1],
      options => { type => Hash[String[1], Data], value => {} }
    }
    PUPPET

  require 'puppet/datatypes/impl/target'

  implementation_class Puppet::DataTypes::Target
end
