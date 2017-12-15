Puppet::DataTypes.create_type('ExecutionResult') do
  interface <<-PUPPET
    attributes => {
      'result_hash' => Hash[
        String[1],
        Struct[
          Optional[value] => Data,
          Optional[error] => Struct[
            msg => String[1],
            Optional[kind] => String[1],
            Optional[issue_code] => String[1],
            Optional[details] => Hash[String[1], Data]]]]
    },
    functions => {
      count => Callable[[], Integer],
      empty => Callable[[], Boolean],
      error_nodes => Callable[[], ExecutionResult],
      names => Callable[[], Array[String[1]]],
      ok => Callable[[], Boolean],
      ok_nodes => Callable[[], ExecutionResult],
      value => Callable[[String[1]], Variant[Error, Data]],
      values => Callable[[], Array[Variant[Error,Data]]],
      '[]' => Callable[[String[1]], Variant[Error, Data]]
    }
  PUPPET

  require 'puppet/datatypes/impl/execution_result'

  implementation_class Puppet::DataTypes::ExecutionResult
end
