# encoding: UTF-8

Sequel.migration do
  up do
    create_table? :messages do
      primary_key :id
      foreign_key :user_from, :users, null: false, key: [:id]
      foreign_key :user_to, :users, null: false, key: [:id]
      foreign_key :reply_to, :messages, null: true, key: [:id]
      DateTime :time
      String :subject
      String :text, text: true
      Bool :viewed
      index [:user_from]
      index [:user_to]
    end
  end

  down do
    drop_table?(:messages)
  end
end
