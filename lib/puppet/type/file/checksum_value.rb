require 'puppet/util/checksums'
require 'puppet/type/file/data_sync'

module Puppet
  Puppet::Type.type(:file).newproperty(:checksum_value) do
    include Puppet::Util::Checksums
    include Puppet::DataSync

    desc "The checksum of the source contents. Only md5 and sha256 are supported when
      specifying this parameter. If this parameter is set, source_permissions will be
      assumed to be false, and ownership and permissions will not be read from source."

    def insync?(is)
      # If checksum_value and source are specified, manage the file contents.
      # Otherwise the content property will manage syncing.
      if resource.parameter(:source).nil?
        return true
      end

      checksum_insync?(resource.parameter(:source), is, true) {|_is| super(_is)}
    end

    def property_matches?(current, desired)
      return true if super(current, desired)
      return date_matches?(resource.parameter(:checksum).value, current, desired)
    end

    def retrieve
      # If checksum_value and source are specified, manage the file contents.
      # Otherwise the content property will manage syncing. Don't compute the checksum twice.
      if resource.parameter(:source).nil?
        return nil
      end

      result = retrieve_checksum(resource)
      # If the returned type matches the util/checksums format (prefixed with the type),
      # strip the checksum type.
      result = sumdata(result) if checksum?(result)
      result
    end

    def sync
      if resource.parameter(:source).nil?
        devfail "checksum_value#sync should not be called without a source parameter"
      end

      # insync? only returns false if it expects to manage the file content,
      # so instruct the resource to write its contents.
      contents_sync(resource.parameter(:source))
    end

  end
end
