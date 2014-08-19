# Store a specified file in our filebucket.
Puppet::Face.define(:file, '0.0.1') do
  action :store do |*args|
    summary "Store a file in the local filebucket."
    arguments "<file>"
    returns "Nothing."
    examples <<-EOT
      Store a file:

      $ puppet file store /root/.bashrc
    EOT

    when_invoked do |path, options|
      file = Puppet::FileBucket::File.new(Puppet::FileSystem.pathname(path))

      Puppet::FileBucket::File.indirection.terminus_class = :file
      Puppet::FileBucket::File.indirection.save file
      file.checksum
    end
  end
end
