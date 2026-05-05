# encoding: UTF-8

Sequel.migration do
  up do
    alter_table(:assessments) do
      set_column_allow_null :start_time_evaluation
      set_column_allow_null :end_time_evaluation
      set_column_allow_null :start_time_feedback
      set_column_allow_null :end_time_feedback
    end
  end

  down do
    alter_table(:assessments) do
      set_column_not_null :start_time_evaluation
      set_column_not_null :end_time_evaluation
      set_column_not_null :start_time_feedback
      set_column_not_null :end_time_feedback
    end
  end
end
