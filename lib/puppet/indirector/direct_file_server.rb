# frozen_string_literal: true
require_relative '../../puppet/file_serving/terminus_helper'
require_relative '../../puppet/indirector/terminus'

class Puppet::Indirector::DirectFileServer < Puppet::Indirector::Terminus

  include Puppet::FileServing::TerminusHelper

  def find(request)
    return nil unless Puppet::FileSystem.exist?(request.key)

    path2instance(request, request.key)
  end

  def search(request)
    return nil unless Puppet::FileSystem.exist?(request.key)

    path2instances(request, request.key)
  end
end
