# frozen_string_literal: true

module Puppet::HTTP::ResponseConverter
  module_function

  # Borrowed from puppetserver, see https://github.com/puppetlabs/puppetserver/commit/a1ebeaaa5af590003ccd23c89f808ba4f0c89609
  def to_ruby_response(response)
    str_code = response.code.to_s

    # Copied from Net::HTTPResponse because it is private there.
    clazz = Net::HTTPResponse::CODE_TO_OBJ[str_code] or
      Net::HTTPResponse::CODE_CLASS_TO_OBJ[str_code[0, 1]] or
      Net::HTTPUnknownResponse
    result = clazz.new(nil, str_code, nil)
    result.body = response.body
    # This is nasty, nasty.  But apparently there is no way to create
    # an instance of Net::HttpResponse from outside of the library and have
    # the body be readable, unless you do stupid things like this.
    result.instance_variable_set(:@read, true)
    response.each_header do |k, v|
      result[k] = v
    end
    result
  end
end
