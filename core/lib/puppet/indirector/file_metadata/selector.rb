require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/code'
require 'puppet/file_serving/terminus_selector'

class Puppet::Indirector::FileMetadata::Selector < Puppet::Indirector::Code
  desc "Select the terminus based on the request"
  include Puppet::FileServing::TerminusSelector

  def get_terminus(request)
    indirection.terminus(select(request))
  end

  def find(request)
    get_terminus(request).find(request)
  end

  def search(request)
    get_terminus(request).search(request)
  end

  def authorized?(request)
    terminus = get_terminus(request)
    if terminus.respond_to?(:authorized?)
      terminus.authorized?(request)
    else
      true
    end
  end
end
