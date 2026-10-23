Sequel.migration do
  change do
    alter_table(:courses) do
      add_column :timezone, String
    end
  end
end
