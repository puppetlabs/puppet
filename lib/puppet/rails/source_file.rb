class Puppet::Rails::SourceFile < ActiveRecord::Base
    has_one :host
    has_one :resource

    def to_label
      "#{self.filename}"
    end
end
