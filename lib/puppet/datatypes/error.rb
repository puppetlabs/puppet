Puppet::DataTypes.create_type('Error') do
  interface <<-PUPPET
    type_parameters => {
      kind => Optional[Variant[String,Regexp,Type[Enum],Type[Pattern],Type[NotUndef],Type[Undef]]],
      issue_code => Optional[Variant[String,Regexp,Type[Enum],Type[Pattern],Type[NotUndef],Type[Undef]]]
    },
    attributes => {
      message => String[1],
      kind => { type => Optional[String[1]], value => undef },
      issue_code => { type => Optional[String[1]], value => undef },
      partial_result => { type => Data, value => undef },
      details => { type => Optional[Hash[String[1],Data]], value => undef },
    }
    PUPPET

  require 'puppet/datatypes/impl/error'

  implementation_class Puppet::DataTypes::Error
end