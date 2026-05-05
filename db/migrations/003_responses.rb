# encoding: UTF-8

Sequel.migration do
  up do
    create_table? :student_assessments do
      primary_key :id
      foreign_key :team_id, :teams, null: false, key: [:id]
      foreign_key :student_from, :users, null: false, key: [:id]
      foreign_key :student_to, :users, null: false, key: [:id]
      TrueClass :complete, default: false, null: false
      TrueClass :saved, default: false, null: false
      DateTime :sent
      index %i[team_id student_from student_to], unique: true
    end

    create_table? :assessment_responses do
      Integer :student_assessment_id
      String :criterion_id, size: 50
      foreign_key [:criterion_id], :criteria, null: false, name: 'fk_sc_criterion_id'
      foreign_key [:student_assessment_id], :student_assessments, null: false, key: [:id]
      String :response_value, text: true
      TrueClass :omitted, default: false, null: false
      primary_key %i[student_assessment_id criterion_id], name: :students_criteria_pk
    end
  end

  down do
    drop_table?(:assessment_responses, :student_assessments)
  end
end
