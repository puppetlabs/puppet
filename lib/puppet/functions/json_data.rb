# @since 4.8.0
#
Puppet::Functions.create_function(:json_data) do
  dispatch :json_data do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  def json_data(options, context)
    path = options['path']
    context.cached_file_data(path) do |content|
      begin
        JSON.parse(content)
      rescue JSON::ParserError => ex
        # Filename not included in message, so we add it here.
        raise Puppet::DataBinding::LookupError, "Unable to parse (#{path}): #{ex.message}"
      end
    end
  end
end
