
module Puppet::InfoService
  require 'puppet/info_service/class_information_service'
  def self.classes_per_environment(env_file_hash)
    Puppet::InfoService::ClassInformationService.new.classes_per_environment(env_file_hash)
  end
end
