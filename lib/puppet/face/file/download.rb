# Download a specified file into the local filebucket.
Puppet::Face.define(:file, '0.0.1') do
  action :download do |*args|
    when_invoked do |sum, options|
      if sum =~ /^puppet:\/\// # it's a puppet url
        require 'puppet/file_serving'
        require 'puppet/file_serving/content'
        raise "Could not find metadata for #{sum}" unless content = Puppet::FileServing::Content.indirection.find(sum)
        file = Puppet::FileBucket::File.new(content.content)
      else
        tester = Object.new
        tester.extend(Puppet::Util::Checksums)

        type    = tester.sumtype(sum)
        sumdata = tester.sumdata(sum)

        key = "#{type}/#{sumdata}"

        Puppet::FileBucket::File.indirection.terminus_class = :file
        if Puppet::FileBucket::File.indirection.find(key)
          Puppet.info "Content for '#{sum}' already exists"
          return
        end

        Puppet::FileBucket::File.indirection.terminus_class = :rest
        raise "Could not download content for '#{sum}'" unless file = Puppet::FileBucket::File.indirection.find(key)
      end


      Puppet::FileBucket::File.indirection.terminus_class = :file
      Puppet.notice "Saved #{sum} to filebucket"
      Puppet::FileBucket::File.indirection.save file
      return nil
    end
  end
end
