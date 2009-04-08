module Puppet::Util::CollectionMerger
    def ar_hash_merge(db_hash, mem_hash, args)
        (db_hash.keys | mem_hash.keys).each do |key|
            if (db_hash[key] && mem_hash[key])
                # in both, update value
                args[:modify].call(db_hash[key], mem_hash[key])
            elsif (db_hash[key])
                # in db, not memory, delete from database
                args[:delete].call(db_hash[key])
            else
                # in mem, not in db, insert into the database
                args[:create].call(key, mem_hash[key])
            end
        end
    end
end

