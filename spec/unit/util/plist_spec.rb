# coding: utf-8

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
  let(:ascii_xml_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>RecordName</key>
         <array>
           <string>Timișoara</string>
           <string>Tōkyō</string>
         </array>
     </dict>
     </plist>'.force_encoding(Encoding::US_ASCII)
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
  let(:ascii_xml_plist_hash) { {"RecordName"=>["Timișoara", "Tōkyō"]} }
  let(:plist_path) { file_containing('sample.plist', valid_xml_plist) }
  let(:binary_plist_magic_number) { 'bplist00' }
  let(:bad_xml_doctype) { '<!DOCTYPE plist PUBLIC -//Apple Computer' }
  let(:good_xml_doctype) { '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' }

  describe "#read_plist_file" do
    it "calls #convert_cfpropertylist_to_native_types on a plist object when a valid binary plist is read" do
      allow(subject).to receive(:read_file_with_offset).with(plist_path, 8).and_return(binary_plist_magic_number)
      allow(subject).to receive(:new_cfpropertylist).with({:file => plist_path}).and_return('plist_object')
      expect(subject).to receive(:convert_cfpropertylist_to_native_types).with('plist_object').and_return('plist_hash')
      expect(subject.read_plist_file(plist_path)).to eq('plist_hash')
    end

    it "returns a valid hash when a valid XML plist is read" do
      allow(subject).to receive(:read_file_with_offset).with(plist_path, 8).and_return('notbinary')
      allow(subject).to receive(:open_file_with_args).with(plist_path, 'r:UTF-8').and_return(valid_xml_plist)
      expect(subject.read_plist_file(plist_path)).to eq(valid_xml_plist_hash)
    end

    it "raises a debug message and replaces a bad XML plist doctype should one be encountered" do
      allow(subject).to receive(:read_file_with_offset).with(plist_path, 8).and_return('notbinary')
      allow(subject).to receive(:open_file_with_args).with(plist_path, 'r:UTF-8').and_return(bad_xml_doctype)
      expect(subject).to receive(:new_cfpropertylist).with({:data => good_xml_doctype}).and_return('plist_object')
      allow(subject).to receive(:convert_cfpropertylist_to_native_types).with('plist_object').and_return('plist_hash')
      expect(Puppet).to receive(:debug).with("Had to fix plist with incorrect DOCTYPE declaration: #{plist_path}")
      expect(subject.read_plist_file(plist_path)).to eq('plist_hash')
    end

    it "attempts to read pure xml using plutil when reading an improperly formatted service plist" do
      allow(subject).to receive(:read_file_with_offset).with(plist_path, 8).and_return('notbinary')
      allow(subject).to receive(:open_file_with_args).with(plist_path, 'r:UTF-8').and_return(invalid_xml_plist)
      expect(Puppet).to receive(:debug).with(/^Failed with CFFormatError/)
      expect(Puppet).to receive(:debug).with("Plist #{plist_path} ill-formatted, converting with plutil")
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['/usr/bin/plutil', '-convert', 'xml1', '-o', '-', plist_path],
              {:failonfail => true, :combine => true})
        .and_return(Puppet::Util::Execution::ProcessOutput.new(valid_xml_plist, 0))
      expect(subject.read_plist_file(plist_path)).to eq(valid_xml_plist_hash)
    end

    it "returns nil when direct parsing and plutil conversion both fail" do
      allow(subject).to receive(:read_file_with_offset).with(plist_path, 8).and_return('notbinary')
      allow(subject).to receive(:open_file_with_args).with(plist_path, 'r:UTF-8').and_return(non_plist_data)
      expect(Puppet).to receive(:debug).with(/^Failed with (CFFormatError|NoMethodError)/)
      expect(Puppet).to receive(:debug).with("Plist #{plist_path} ill-formatted, converting with plutil")
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['/usr/bin/plutil', '-convert', 'xml1', '-o', '-', plist_path],
              {:failonfail => true, :combine => true})
        .and_raise(Puppet::ExecutionFailure, 'boom')
      expect(subject.read_plist_file(plist_path)).to eq(nil)
    end

    it "returns nil when file is a non-plist binary blob" do
      allow(subject).to receive(:read_file_with_offset).with(plist_path, 8).and_return('notbinary')
      allow(subject).to receive(:open_file_with_args).with(plist_path, 'r:UTF-8').and_return(binary_data)
      expect(Puppet).to receive(:debug).with(/^Failed with (CFFormatError|ArgumentError)/)
      expect(Puppet).to receive(:debug).with("Plist #{plist_path} ill-formatted, converting with plutil")
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['/usr/bin/plutil', '-convert', 'xml1', '-o', '-', plist_path],
              {:failonfail => true, :combine => true})
        .and_raise(Puppet::ExecutionFailure, 'boom')
      expect(subject.read_plist_file(plist_path)).to eq(nil)
    end
  end

  describe "#parse_plist" do
    it "returns a valid hash when a valid XML plist is provided" do
      expect(subject.parse_plist(valid_xml_plist)).to eq(valid_xml_plist_hash)
    end

    it "returns a valid hash when an ASCII XML plist is provided" do
      expect(subject.parse_plist(ascii_xml_plist)).to eq(ascii_xml_plist_hash)
    end

    it "raises a debug message and replaces a bad XML plist doctype should one be encountered" do
      expect(subject).to receive(:new_cfpropertylist).with({:data => good_xml_doctype}).and_return('plist_object')
      allow(subject).to receive(:convert_cfpropertylist_to_native_types).with('plist_object')
      expect(Puppet).to receive(:debug).with("Had to fix plist with incorrect DOCTYPE declaration: #{plist_path}")
      subject.parse_plist(bad_xml_doctype, plist_path)
    end

    it "raises a debug message with malformed plist" do
      allow(subject).to receive(:convert_cfpropertylist_to_native_types).with('plist_object')
      expect(Puppet).to receive(:debug).with(/^Failed with CFFormatError/)
      subject.parse_plist("<plist><dict><key>Foo</key>")
    end
  end
end
