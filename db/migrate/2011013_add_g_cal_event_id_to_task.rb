class AddGCalEventIdToTask < ActiveRecord::Migration
  def self.up
    add_column :tasks, :gcal_event_id, :string
  end

  def self.down
    remove_column :tasks, :gcal_event_id
  end
end
