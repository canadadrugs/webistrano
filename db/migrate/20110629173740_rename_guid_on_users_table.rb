class RenameGuidOnUsersTable < ActiveRecord::Migration
  def self.up
    rename_column :users, :guid, :ldap_id
  end

  def self.down
    rename_column :users, :ldap_id, :guid
  end
end
