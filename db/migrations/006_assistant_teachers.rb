# encoding: UTF-8

Sequel.migration do
  up do
    create_table? :assistant_teachers do
      foreign_key :course_id, :courses, null: false
      foreign_key :teacher_id, :users, null: false, key: [:id]
      primary_key %i[course_id teacher_id]
    end
  end

  down do
    drop_table?(:assistant_teachers)
  end
end
