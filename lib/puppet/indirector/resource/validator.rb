module Puppet::Resource::Validator
  def validate_key(request)
    type, title = request.key.split('/', 2)
    unless type.downcase == request.instance.type.downcase and title == request.instance.title
      raise Puppet::Indirector::ValidationError, _("Resource instance does not match request key")
    end
  end
end
