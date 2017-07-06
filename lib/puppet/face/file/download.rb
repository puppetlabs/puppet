# Download a specified file into the local filebucket.
Puppet::Face.define(:file, '0.0.1') do
  action :download do |*args|
    summary "Download a file into the local filebucket."
    arguments "( {md5}<checksum> | <puppet_url> )"
    returns "Nothing."
    description <<-EOT
      Downloads a file from the puppet master's filebucket and duplicates it in
      the local filebucket. This action's checksum syntax differs from `find`'s,
      and it can accept a <puppet:///> URL.
    EOT
    examples <<-'EOT'
      Download a file by URL:

      $ puppet file download puppet:///modules/editors/vim/.vimrc

      Download a file by MD5 sum:

      $ puppet file download {md5}8f798d4e754db0ac89186bbaeaf0af18
    EOT

    when_invoked do |sum, options|
      if sum =~ /^puppet:\/\// # it's a puppet url
        require 'puppet/file_serving'
        require 'puppet/file_serving/content'
        unless content = Puppet::FileServing::Content.indirection.find(sum)
          raise "Could not find metadata for #{sum}"
        end
        pathname = Puppet::FileSystem.pathname(content.full_path())
        file = Puppet::FileBucket::File.new(pathname)
      else
        tester = Puppet::Util::Checksums

        type    = tester.sumtype(sum)
        sumdata = tester.sumdata(sum)

        key = "#{type}/#{sumdata}"

        Puppet::FileBucket::File.indirection.terminus_class = :file
        if Puppet::FileBucket::File.indirection.head(key)
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
