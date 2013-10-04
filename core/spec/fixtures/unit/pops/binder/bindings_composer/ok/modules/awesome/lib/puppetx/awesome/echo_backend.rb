require 'puppetx/puppet/hiera2_backend'

module Puppetx
  module Awesome
    class EchoBackend < Puppetx::Puppet::Hiera2Backend
      def read_data(directory, file_name)
        {"echo::#{file_name}" => "echo... #{File.basename(directory)}/#{file_name}"}
      end
    end
  end
end