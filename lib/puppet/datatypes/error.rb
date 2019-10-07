Puppet::DataTypes.create_type('Error') do
  interface <<-PUPPET
    type_parameters => {
      kind => Optional[Variant[String,Regexp,Type[Enum],Type[Pattern],Type[NotUndef],Type[Undef]]],
      issue_code => Optional[Variant[String,Regexp,Type[Enum],Type[Pattern],Type[NotUndef],Type[Undef]]]
    },
    attributes => {
      msg => String[1],
      kind => { type => Optional[String[1]], value => undef },
      details => { type => Optional[Hash[String[1],Data]], value => undef },
      issue_code => { type => Optional[String[1]], value => undef },
    },
    functions => {
      message => Callable[[], String[1]]
    }
    PUPPET

  require 'puppet/datatypes/impl/error'

  implementation_class Puppet::DataTypes::Error
end
