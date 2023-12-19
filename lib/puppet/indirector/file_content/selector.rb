# frozen_string_literal: true

require_relative '../../../puppet/file_serving/content'
require_relative '../../../puppet/indirector/file_content'
require_relative '../../../puppet/indirector/code'
require_relative '../../../puppet/file_serving/terminus_selector'

class Puppet::Indirector::FileContent::Selector < Puppet::Indirector::Code
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
