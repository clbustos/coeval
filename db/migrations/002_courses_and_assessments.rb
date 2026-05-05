# encoding: UTF-8

Sequel.migration do
  up do
    create_table? :criteria do
      String :id, size: 50, primary_key: true
      String :name, null: false
      String :criterion_type
    end

    create_table? :criterion_levels do
      Integer :points, null: false
      String :description, text: true
      String :criterion_id, size: 50, null: false
      foreign_key [:criterion_id], :criteria, null: false, name: 'fk_cl_criterion_id'
      primary_key %i[criterion_id points], name: :criterion_levels_pk
    end

    create_table? :courses do
      primary_key :id
      String :name, null: false
      String :description, text: true
      foreign_key :institution_id, :institutions, null: false
      TrueClass :active, default: true, null: false
      foreign_key :teacher_id, :users, null: false, key: [:id]
    end

    create_table? :assessments do
      primary_key :id
      foreign_key :course_id, :courses, null: false
      TrueClass :active, default: true, null: false
      String :name, null: false
      String :description, text: true
      DateTime :start_time_evaluation, null: false
      DateTime :end_time_evaluation, null: false
      DateTime :start_time_feedback, null: false
      DateTime :end_time_feedback, null: false
      String :grade_system, size: 64, null: true
      Integer :grade_parameter_1, null: true
      Integer :grade_parameter_2, null: true
    end

    create_table? :assessment_criteria do
      String :criterion_id, size: 50, null: false
      foreign_key [:criterion_id], :criteria, null: false, name: 'fk_as_criterion_id'
      foreign_key :assessment_id, :assessments
      Integer :criterion_order
      primary_key %i[criterion_id assessment_id]
    end

    create_table? :student_courses do
      foreign_key :course_id, :courses, null: false
      foreign_key :student_id, :users, null: false, key: [:id]
      primary_key %i[course_id student_id]
    end

    create_table? :teams do
      primary_key :id
      String :name, text: true
      foreign_key :assessment_id, :assessments, null: false, key: [:id]
      foreign_key :teacher_id, :users, null: false, key: [:id]
    end

    create_table? :student_teams do
      foreign_key :team_id, :teams, null: false, key: [:id]
      foreign_key :student_id, :users, null: false, key: [:id]
      primary_key %i[team_id student_id]
    end
  end

  down do
    drop_table?(:student_teams, :teams, :student_courses, :assessment_criteria, :assessments, :courses, :criterion_levels, :criteria)
  end
end
