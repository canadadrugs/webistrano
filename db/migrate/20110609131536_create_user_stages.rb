class CreateUserStages < ActiveRecord::Migration
  def self.up
    create_table :user_stages, :force => true do |t|
      t.integer :user_id
      t.integer :stage_id
    end
    add_index :user_stages, [:user_id, :stage_id]
  end

  def self.down
    drop_table :user_stages
  end
end
