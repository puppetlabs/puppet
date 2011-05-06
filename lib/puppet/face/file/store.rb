# Store a specified file in our filebucket.
Puppet::Face.define(:file, '0.0.1') do
  action :store do |*args|
    when_invoked do |path, options|
      file = Puppet::FileBucket::File.new(File.read(path))

      Puppet::FileBucket::File.indirection.terminus_class = :file
      Puppet::FileBucket::File.indirection.save file
      file.checksum
    end
  end
end
