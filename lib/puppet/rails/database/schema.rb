class Puppet::Rails::Schema
    def self.init
        oldout = nil
        Puppet::Util.benchmark(Puppet, :notice, "Initialized database") do
            # We want to rewrite stdout, so we don't get migration messages.
            oldout = $stdout
            $stdout = File.open("/dev/null", "w")
            ActiveRecord::Schema.define do
                create_table :resources do |t|
                    t.column :title, :string, :null => false
                    t.column :restype,  :string, :null => false
                    t.column :host_id, :integer
                    t.column :source_file_id, :integer
                    t.column :exported, :boolean
                    t.column :line, :integer
                    t.column :updated_at, :date
                end

                create_table :source_files do |t| 
                    t.column :filename, :string
                    t.column :path, :string
                    t.column :updated_at, :date
                end

                create_table :puppet_classes do |t| 
                    t.column :name, :string
                    t.column :host_id, :integer
                    t.column :source_file_id, :integer
                    t.column :updated_at, :date
                end

                create_table :hosts do |t|
                    t.column :name, :string, :null => false
                    t.column :ip, :string
                    t.column :connect, :date
                    #Use updated_at to automatically add timestamp on save.
                    t.column :updated_at, :date
                    t.column :source_file_id, :integer
                end

                create_table :fact_names do |t| 
                    t.column :name, :string, :null => false
                    t.column :host_id, :integer, :null => false
                    t.column :updated_at, :date
                end

                create_table :fact_values do |t| 
                    t.column :value, :text, :null => false
                    t.column :fact_name_id, :integer, :null => false
                    t.column :updated_at, :date
                end 

                create_table :param_values do |t|
                    t.column :value,  :text, :null => false
                    t.column :param_name_id, :integer, :null => false
                    t.column :updated_at, :date
                end
         
                create_table :param_names do |t| 
                    t.column :name, :string, :null => false
                    t.column :resource_id, :integer
                    t.column :line, :integer
                    t.column :updated_at, :date
                end

                create_table :tags do |t| 
                    t.column :name, :string
                    t.column :updated_at, :date
                end 

                create_table :taggings do |t| 
                    t.column :tag_id, :integer
                    t.column :taggable_id, :integer
                    t.column :taggable_type, :string
                    t.column :updated_at, :date
                end
            end
            $stdout.close
            $stdout = oldout
            oldout = nil
        end
    ensure
        $stdout = oldout if oldout
    end
end

# $Id$
