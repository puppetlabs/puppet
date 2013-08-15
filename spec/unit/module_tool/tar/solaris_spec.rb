require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Tar::Solaris do
  let(:sourcefile) { '/the/module.tar.gz' }
  let(:destdir)    { '/the/dest/dir' }
  let(:sourcedir)  { '/the/src/dir' }
  let(:destfile)   { '/the/dest/file.tar.gz' }

  it "unpacks a tar file" do
    Puppet::Util::Execution.expects(:execute).with("gtar xzf #{sourcefile} --no-same-permissions --no-same-owner -C #{destdir}")
    Puppet::Util::Execution.expects(:execute).with("find #{destdir} -type d -exec chmod 755 {} +")
    Puppet::Util::Execution.expects(:execute).with("find #{destdir} -type f -exec chmod 644 {} +")
    Puppet::Util::Execution.expects(:execute).with("chown -R <owner:group> #{destdir}")
    subject.unpack(sourcefile, destdir, '<owner:group>')
  end

  it "packs a tar file" do
    Puppet::Util::Execution.expects(:execute).with("tar cf - #{sourcedir} | gzip -c > #{destfile}")
    subject.pack(sourcedir, destfile)
  end
end
