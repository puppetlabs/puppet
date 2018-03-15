require 'spec_helper'
require 'puppet/util/plist'
require 'puppet_spec/files'

describe Puppet::Util::Plist, :if => Puppet.features.cfpropertylist? do
  include PuppetSpec::Files

  let(:valid_xml_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>LastUsedPrinters</key>
       <array>
         <dict>
                 <key>Network</key>
                 <string>10.85.132.1</string>
                 <key>PrinterID</key>
                 <string>baskerville_corp_puppetlabs_net</string>
         </dict>
         <dict>
                 <key>Network</key>
                 <string>10.14.96.1</string>
                 <key>PrinterID</key>
                 <string>Statler</string>
         </dict>
       </array>
    </dict>
    </plist>'
  end
  let(:invalid_xml_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>LastUsedPrinters</key>
       <array>
         <dict>
                 <!-- this comment is --terrible -->
                 <key>Network</key>
                 <string>10.85.132.1</string>
                 <key>PrinterID</key>
                 <string>baskerville_corp_puppetlabs_net</string>
         </dict>
         <dict>
                 <key>Network</key>
                 <string>10.14.96.1</string>
                 <key>PrinterID</key>
                 <string>Statler</string>
         </dict>
       </array>
    </dict>
    </plist>'
  end
  let(:non_plist_data) do
    "Take my love, take my land
     Take me where I cannot stand
     I don't care, I'm still free
     You can't take the sky from me."
  end
  let(:binary_data) do
    "\xCF\xFA\xED\xFE\a\u0000\u0000\u0001\u0003\u0000\u0000\x80\u0002\u0000\u0000\u0000\u0012\u0000\u0000\u0000\b"
  end
  let(:valid_xml_plist_hash) { {"LastUsedPrinters"=>[{"Network"=>"10.85.132.1", "PrinterID"=>"baskerville_corp_puppetlabs_net"}, {"Network"=>"10.14.96.1", "PrinterID"=>"Statler"}]} }
  let(:plist_path) { file_containing('sample.plist', valid_xml_plist) }
  let(:binary_plist_magic_number) { 'bplist00' }
  let(:bad_xml_doctype) { '<!DOCTYPE plist PUBLIC -//Apple Computer' }
  let(:good_xml_doctype) { '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' }

  describe "#read_plist_file" do
    it "calls #convert_cfpropertylist_to_native_types on a plist object when a valid binary plist is read" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns(binary_plist_magic_number)
      subject.stubs(:new_cfpropertylist).with({:file => plist_path}).returns('plist_object')
      subject.expects(:convert_cfpropertylist_to_native_types).with('plist_object').returns('plist_hash')
      expect(subject.read_plist_file(plist_path)).to eq('plist_hash')
    end
    it "returns a valid hash when a valid XML plist is read" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(valid_xml_plist)
      expect(subject.read_plist_file(plist_path)).to eq(valid_xml_plist_hash)
    end
    it "raises a debug message and replaces a bad XML plist doctype should one be encountered" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(bad_xml_doctype)
      subject.expects(:new_cfpropertylist).with({:data => good_xml_doctype}).returns('plist_object')
      subject.stubs(:convert_cfpropertylist_to_native_types).with('plist_object').returns('plist_hash')
      Puppet.expects(:debug).with("Had to fix plist with incorrect DOCTYPE declaration: #{plist_path}")
      expect(subject.read_plist_file(plist_path)).to eq('plist_hash')
    end
    it "attempts to read pure xml using plutil when reading an improperly formatted service plist" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(invalid_xml_plist)
      Puppet.expects(:debug).with(regexp_matches(/^Failed with CFFormatError/))
      Puppet.expects(:debug).with("Plist #{plist_path} ill-formatted, converting with plutil")
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/plutil', '-convert', 'xml1', '-o', '-', plist_path],
                                                     {:failonfail => true, :combine => true}).returns(valid_xml_plist)
      expect(subject.read_plist_file(plist_path)).to eq(valid_xml_plist_hash)
    end
    it "returns nil when direct parsing and plutil conversion both fail" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(non_plist_data)
      Puppet.expects(:debug).with(regexp_matches(/^Failed with (CFFormatError|NoMethodError)/))
      Puppet.expects(:debug).with("Plist #{plist_path} ill-formatted, converting with plutil")
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/plutil', '-convert', 'xml1', '-o', '-', plist_path],
                                                     {:failonfail => true, :combine => true}).raises(Puppet::ExecutionFailure, 'boom')
      expect(subject.read_plist_file(plist_path)).to eq(nil)
    end
    it "returns nil when file is a non-plist binary blob" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(binary_data)
      Puppet.expects(:debug).with(regexp_matches(/^Failed with (CFFormatError|ArgumentError)/))
      Puppet.expects(:debug).with("Plist #{plist_path} ill-formatted, converting with plutil")
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/plutil', '-convert', 'xml1', '-o', '-', plist_path],
                                                     {:failonfail => true, :combine => true}).raises(Puppet::ExecutionFailure, 'boom')
      expect(subject.read_plist_file(plist_path)).to eq(nil)
    end
  end

  describe "#parse_plist" do
    it "returns a valid hash when a valid XML plist is provided" do
      expect(subject.parse_plist(valid_xml_plist)).to eq(valid_xml_plist_hash)
    end
    it "raises a debug message and replaces a bad XML plist doctype should one be encountered" do
      subject.expects(:new_cfpropertylist).with({:data => good_xml_doctype}).returns('plist_object')
      subject.stubs(:convert_cfpropertylist_to_native_types).with('plist_object')
      Puppet.expects(:debug).with("Had to fix plist with incorrect DOCTYPE declaration: #{plist_path}")
      subject.parse_plist(bad_xml_doctype, plist_path)
    end
    it "raises a debug message with malformed plist" do
      subject.stubs(:convert_cfpropertylist_to_native_types).with('plist_object')
      Puppet.expects(:debug).with(regexp_matches(/^Failed with CFFormatError/))
      subject.parse_plist("<plist><dict><key>Foo</key>")
    end
  end
end
