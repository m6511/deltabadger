class AddEmailAlertsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_low_funds, :boolean, default: true, null: false
    add_column :users, :email_bot_errors, :boolean, default: true, null: false
    add_column :users, :email_bot_stopped, :boolean, default: true, null: false
  end
end
