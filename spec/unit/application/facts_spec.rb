require 'spec_helper'
require 'puppet/application/facts'

describe Puppet::Application::Facts do
  let(:app) { Puppet::Application[:facts] }
  let(:values) { {"filesystems" => "apfs,autofs,devfs", "macaddress" => "64:52:11:22:03:2e"} }

  before :each do
    Puppet::Node::Facts.indirection.terminus_class = :memory
  end

  it "returns facts for a given node" do
    facts = Puppet::Node::Facts.new('whatever', values)
    Puppet::Node::Facts.indirection.save(facts)

    app.command_line.args = %w{find whatever --render-as yaml}

    # due to PUP-10105 we emit the class tag when we shouldn't
    expected = Regexp.new(<<~END)
      --- !ruby/object:Puppet::Node::Facts
      name: whatever
      values:
        filesystems: apfs,autofs,devfs
        macaddress: "64:52:11:22:03:2e"
    END

    expect {
      app.run
    }.to exit_with(0)
     .and output(expected).to_stdout
  end

  it "returns facts for the current node when the name is omitted" do
    facts = Puppet::Node::Facts.new(Puppet[:certname], values)
    Puppet::Node::Facts.indirection.save(facts)

    app.command_line.args = %w{find --render-as yaml}

    # due to PUP-10105 we emit the class tag when we shouldn't
    expected = Regexp.new(<<~END)
      --- !ruby/object:Puppet::Node::Facts
      name: #{Puppet[:certname]}
      values:
        filesystems: apfs,autofs,devfs
        macaddress: "64:52:11:22:03:2e"
    END

    expect {
      app.run
    }.to exit_with(0)
     .and output(expected).to_stdout
  end

  context 'when show action is called' do
    let(:expected) { <<~END }
      {
        "filesystems": "apfs,autofs,devfs",
        "macaddress": "64:52:11:22:03:2e"
      }
    END

    before :each do
      Puppet::Node::Facts.indirection.terminus_class = :facter
      allow(Facter).to receive(:resolve).and_return(values)
      app.command_line.args = %w{show}
    end

    it 'correctly displays facts with default formatting' do
      expect {
        app.run
      }.to exit_with(0)
       .and output(expected).to_stdout
    end

    it 'displays a single fact value' do
      app.command_line.args << 'filesystems' << '--value-only'
      expect {
        app.run
      }.to exit_with(0)
       .and output("apfs,autofs,devfs\n").to_stdout
    end

    it "warns and ignores value-only when multiple fact names are specified" do
      app.command_line.args << 'filesystems' << 'macaddress' << '--value-only'
      expect {
        app.run
      }.to exit_with(0)
       .and output(expected).to_stdout
       .and output(/it can only be used when querying for a single fact/).to_stderr
    end

    {
      "type_hash" => [{'a' => 2}, "{\n  \"a\": 2\n}"],
      "type_array" => [[], "[\n\n]"],
      "type_string" => ["str", "str"],
      "type_int" => [1, "1"],
      "type_float" => [1.0, "1.0"],
      "type_true" => [true, "true"],
      "type_false" => [false, "false"],
      "type_nil" => [nil, ""],
      "type_sym" => [:sym, "sym"]
    }.each_pair do |name, values|
      it "renders '#{name}' as '#{values.last}'" do
        fact_value = values.first
        fact_output = values.last

        allow(Facter).to receive(:resolve).and_return({name => fact_value})

        app.command_line.args << name << '--value-only'
        expect {
          app.run
        }.to exit_with(0)
         .and output("#{fact_output}\n").to_stdout
      end
    end
  end

  context 'when diff action is called' do
    let(:facter3_facts) { <<~END }
{
  "hypervisors": {
    "vmware": {
      "version": ""
    }
  },
  "networking": {
    "interfaces": {
      "lo": {
        "bindings6": [
          {
            "network": "::1"
          }
        ]
      },
      "em0.1": {
        "ip": "0.0.0.0"
      }
    }
  },
  "macaddress": "64:52:11:22:03:2e",
  "obsolete_fact": "true",
  "mountpoints": {
    "/var": {
      "options": [
        "noatime",
        "journaled",
        "nobrowse"
      ]
    }
  }
}
END

    let(:facter4_facts) { <<~END }
{
  "hypervisors": {
    "vmware": {
      "version": "ESXi 6.7"
    }
  },
  "networking": {
    "interfaces": {
      "lo": {
        "bindings6": [
          {
            "network": "::1",
            "scope6": "host"
          }
        ]
      },
      "em0.1": {
        "ip": "127.0.0.1"
      }
    }
  },
  "macaddress": "64:52:11:22:03:2e",
  "mountpoints": {
    "/var": {
      "options": [
        "noatime",
        "nobrowse",
        "journaled"
      ]
    }
  }
}
END

    before :each do
      Puppet::Node::Facts.indirection.terminus_class = :facter
      app.command_line.args = %w{diff}

      allow(Facter).to receive(:value).with('facterversion').and_return('3.99.0')
      allow(Puppet::Util::Execution).to receive(:execute).with(/puppet facts show --no-facterng/).and_return(facter3_facts)
      allow(Puppet::Util::Execution).to receive(:execute).with(/puppet facts show --facterng/).and_return(facter4_facts)
    end

    # Workaround for YAML issue on Ubuntu where null values get space as key
    let(:regex) { false }
    shared_examples_for 'correctly rendering output' do |render_format|
      it 'correctly displays output' do
        app.command_line.args << '--structured' if structured
        app.command_line.args << '--exclude' << exclude if exclude
        app.command_line.args << '--render-as' << render_format if render_format
        expect {
          app.run
        }.to exit_with(0)
         .and output(regex ? /#{expected_output}/ : expected_output).to_stdout
      end
    end

    context 'when no exclude regex is provided via CLI' do
      let(:exclude) { nil }
      context 'when structured is requested' do
        let(:structured) { true }
        context 'when rendering is set to default' do
          let(:expected_output) { <<~END }
{
  "hypervisors": {
    "vmware": {
      "version": {
        "new_value": "ESXi 6.7",
        "old_value": ""
      }
    }
  },
  "mountpoints": {
    "/var": {
      "options": {
        "1": {
          "new_value": "nobrowse",
          "old_value": "journaled"
        },
        "2": {
          "new_value": "journaled",
          "old_value": "nobrowse"
        }
      }
    }
  },
  "networking": {
    "interfaces": {
      "em0.1": {
        "ip": {
          "new_value": "127.0.0.1",
          "old_value": "0.0.0.0"
        }
      },
      "lo": {
        "bindings6": {
          "0": {
            "scope6": {
              "new_value": "host",
              "old_value": null
            }
          }
        }
      }
    }
  },
  "obsolete_fact": {
    "new_value": null,
    "old_value": "true"
  }
}
END

          it_behaves_like 'correctly rendering output'
        end

        context 'when rendering is set to yaml' do
          # Workaround for YAML issue on Ubuntu where null values get space as key
          let(:regex) { true }
          let(:expected_output) { <<~END }
---
hypervisors:
  vmware:
    version:
      :new_value: ESXi 6\.7
      :old_value: ''
mountpoints:
  "/var":
    options:
      1:
        :new_value: nobrowse
        :old_value: journaled
      2:
        :new_value: journaled
        :old_value: nobrowse
networking:
  interfaces:
    em0\.1:
      ip:
        :new_value: 127\.0\.0\.1
        :old_value: 0\.0\.0\.0
    lo:
      bindings6:
        0:
          scope6:
            :new_value: host
            :old_value:\s?
obsolete_fact:
  :new_value:\s?
  :old_value: 'true'
END

          it_behaves_like 'correctly rendering output', 'yaml'
        end

        context 'when rendering is set to json' do
          let(:expected_output) { <<~END }
{"hypervisors":{"vmware":{"version":{"new_value":"ESXi 6.7","old_value":""}}},\
"mountpoints":{"/var":{"options":{"1":{"new_value":"nobrowse","old_value":"journaled"},\
"2":{"new_value":"journaled","old_value":"nobrowse"}}}},"networking":{"interfaces":\
{"em0.1":{"ip":{"new_value":"127.0.0.1","old_value":"0.0.0.0"}},"lo":{"bindings6":\
{"0":{"scope6":{"new_value":"host","old_value":null}}}}}},"obsolete_fact":\
{"new_value":null,"old_value":"true"}}
END

          it_behaves_like 'correctly rendering output', 'json'
        end
      end

      context 'when structured is not requested' do
        let(:structured) { false }
        context 'when rendering is set to default' do
          let(:expected_output) { <<~END }
{
  "hypervisors.vmware.version": {
    "new_value": "ESXi 6.7",
    "old_value": ""
  },
  "mountpoints./var.options.1": {
    "new_value": "nobrowse",
    "old_value": "journaled"
  },
  "mountpoints./var.options.2": {
    "new_value": "journaled",
    "old_value": "nobrowse"
  },
  "networking.interfaces.\\"em0.1\\".ip": {
    "new_value": "127.0.0.1",
    "old_value": "0.0.0.0"
  },
  "networking.interfaces.lo.bindings6.0.scope6": {
    "new_value": "host",
    "old_value": null
  },
  "obsolete_fact": {
    "new_value": null,
    "old_value": "true"
  }
}
END

          it_behaves_like 'correctly rendering output'
        end

        context 'when rendering is set to yaml' do
          # Workaround for YAML issue on Ubuntu where null values get space as key
          let(:regex) { true }
          let(:expected_output) { <<~END }
---
hypervisors\.vmware\.version:
  :new_value: ESXi 6\.7
  :old_value: ''
mountpoints\./var\.options\.1:
  :new_value: nobrowse
  :old_value: journaled
mountpoints\./var\.options\.2:
  :new_value: journaled
  :old_value: nobrowse
networking\.interfaces\."em0\.1"\.ip:
  :new_value: 127\.0\.0\.1
  :old_value: 0\.0\.0\.0
networking\.interfaces\.lo\.bindings6\.0\.scope6:
  :new_value: host
  :old_value:\s?
obsolete_fact:
  :new_value:\s?
  :old_value: 'true'
END

          it_behaves_like 'correctly rendering output', 'yaml'
        end

        context 'when rendering is set to json' do
          let(:expected_output) { <<~END }
{"hypervisors.vmware.version":{"new_value":"ESXi 6.7","old_value":""},\
"mountpoints./var.options.1":{"new_value":"nobrowse","old_value":"journaled"},\
"mountpoints./var.options.2":{"new_value":"journaled","old_value":"nobrowse"},\
"networking.interfaces.\\"em0.1\\".ip":{"new_value":"127.0.0.1",\
"old_value":"0.0.0.0"},"networking.interfaces.lo.bindings6.0.scope6":\
{"new_value":"host","old_value":null},"obsolete_fact":{"new_value":null,\
"old_value":"true"}}
END

          it_behaves_like 'correctly rendering output', 'json'
        end
      end
    end

    context 'when unwanted facts are excluded from diff via CLI option' do
      let(:exclude) { '^mountpoints\./var\.options.*$|^obsolete_fact$|^hypervisors' }
      context 'when structured is requested' do
        let(:structured) { true }
        context 'when rendering is set to default' do
          let(:expected_output) { <<~END }
{
  "networking": {
    "interfaces": {
      "em0.1": {
        "ip": {
          "new_value": "127.0.0.1",
          "old_value": "0.0.0.0"
        }
      },
      "lo": {
        "bindings6": {
          "0": {
            "scope6": {
              "new_value": "host",
              "old_value": null
            }
          }
        }
      }
    }
  }
}
END

          it_behaves_like 'correctly rendering output'
        end

        context 'when rendering is set to yaml' do
          # Workaround for YAML issue on Ubuntu where null values get space as key
          let(:regex) { true }
          let(:expected_output) { <<~END }
---
networking:
  interfaces:
    em0\.1:
      ip:
        :new_value: 127\.0\.0\.1
        :old_value: 0\.0\.0\.0
    lo:
      bindings6:
        0:
          scope6:
            :new_value: host
            :old_value:\s?
END

          it_behaves_like 'correctly rendering output', 'yaml'
        end

        context 'when rendering is set to json' do
          let(:expected_output) { <<~END }
{"networking":{"interfaces":{"em0.1":{"ip":{"new_value":"127.0.0.1",\
"old_value":"0.0.0.0"}},"lo":{"bindings6":{"0":{"scope6":{"new_value":\
"host","old_value":null}}}}}}}
END

          it_behaves_like 'correctly rendering output', 'json'
        end
      end

      context 'when structured is not requested' do
        let(:structured) { false }
        context 'when rendering is set to default' do
          let(:expected_output) { <<~END }
{
  "networking.interfaces.\\"em0.1\\".ip": {
    "new_value": "127.0.0.1",
    "old_value": "0.0.0.0"
  },
  "networking.interfaces.lo.bindings6.0.scope6": {
    "new_value": "host",
    "old_value": null
  }
}
END

          it_behaves_like 'correctly rendering output'
        end

        context 'when rendering is set to yaml' do
          # Workaround for YAML issue on Ubuntu where null values get space as key
          let(:regex) { true }
          let(:expected_output) { <<~END }
---
networking\.interfaces\."em0\.1"\.ip:
  :new_value: 127\.0\.0\.1
  :old_value: 0\.0\.0\.0
networking\.interfaces\.lo\.bindings6\.0\.scope6:
  :new_value: host
  :old_value:\s?
END

          it_behaves_like 'correctly rendering output', 'yaml'
        end

        context 'when rendering is set to json' do
          let(:expected_output) { <<~END }
{"networking.interfaces.\\"em0.1\\".ip":{"new_value":"127.0.0.1",\
"old_value":"0.0.0.0"},"networking.interfaces.lo.bindings6.0.scope6":\
{"new_value":"host","old_value":null}}
END

          it_behaves_like 'correctly rendering output', 'json'
        end
      end
    end
  end

  context 'when default action is called' do
    before :each do
      Puppet::Node::Facts.indirection.terminus_class = :memory
      facts = Puppet::Node::Facts.new('whatever', values)
      Puppet::Node::Facts.indirection.save(facts)
    end

    it 'calls find action' do
      expect {
        app.run
      }.to exit_with(0)
       .and output(anything).to_stdout
      expect(app.action.name).to eq(:find)
    end
  end
end
