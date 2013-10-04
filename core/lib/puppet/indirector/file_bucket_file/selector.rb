require 'puppet/indirector/code'

module Puppet::FileBucketFile
  class Selector < Puppet::Indirector::Code
    desc "Select the terminus based on the request"

    def select(request)
      if request.protocol == 'https'
        :rest
      else
        :file
      end
    end

    def get_terminus(request)
      indirection.terminus(select(request))
    end

    def head(request)
      get_terminus(request).head(request)
    end

    def find(request)
      get_terminus(request).find(request)
    end

    def save(request)
      get_terminus(request).save(request)
    end

    def search(request)
      get_terminus(request).search(request)
    end

    def destroy(request)
      get_terminus(request).destroy(request)
    end

    def authorized?(request)
      terminus = get_terminus(request)
      if terminus.respond_to?(:authorized?)
        terminus.authorized?(request)
      else
        true
      end
    end

    def validate_key(request)
      get_terminus(request).validate(request)
    end
  end
end

