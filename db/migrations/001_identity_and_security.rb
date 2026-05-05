# encoding: UTF-8

Sequel.migration do
  up do
    create_table? :roles do
      String :id, size: 50, primary_key: true
      String :description
    end

    create_table? :institutions do
      primary_key :id
      String :name
    end

    create_table? :users do
      primary_key :id
      String :registration_code, size: 255
      String :login, size: 255
      String :name, text: true
      String :email, size: 255, unique: true, null: true
      String :password, size: 255
      String :language, size: 3
      String :token_password, size: 255
      DateTime :token_datetime
      foreign_key :institution_id, :institutions
      foreign_key :role_id, :roles, type: String, size: 50, null: false, key: [:id]
      TrueClass :active, default: true, null: false
    end

    create_table? :groups do
      primary_key :id
      foreign_key :group_administrator, :users, null: false, key: [:id]
      String :description, text: true
      String :name, size: 255, null: false
    end

    create_join_table?({ user_id: :users, group_id: :groups }, name: :groups_users)

    create_table? :authorizations do
      String :id, size: 50, primary_key: true
      String :description, size: 255
    end

    create_table? :authorizations_roles do
      foreign_key :authorization_id, :authorizations, type: String, size: 50, null: false, key: [:id]
      foreign_key :role_id, :roles, type: String, size: 50, null: false, key: [:id]
      primary_key %i[authorization_id role_id]
      index [:role_id]
    end
  end

  down do
    drop_table?(:authorizations_roles, :authorizations, :groups_users, :groups, :users, :institutions, :roles)
  end
end
