class AddProjectUsersJoinTable < ActiveRecord::Migration
  def self.up
    create_table :projects_users, :id => false do |t|
      t.integer :project_id
      t.integer :user_id
    end
    add_index :projects_users, [:user_id, :project_id], :name => "index_user_project_ids"
  end

  def self.down
    remove_index :projects_users, :name => :index_user_project_ids
    drop_table :projects_users
  end
end