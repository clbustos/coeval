# encoding: UTF-8

Sequel.migration do
  up do
    create_or_replace_view(:assessments_results_raw, <<~SQL)
      SELECT t.assessment_id,t.name as t_name, st.team_id as team_id, stas.id as ass_id,
      st.student_id as student_from, st2.student_id as student_to,
      complete, saved, ac.criterion_id,criterion_type, response_value, min_points, max_points,
      omitted
        FROM teams t INNER JOIN
        student_teams st on t.id=st.team_id  CROSS JOIN student_teams  st2 ON st2.team_id=t.id
        CROSS JOIN assessment_criteria ac ON ac.assessment_id=t.assessment_id
        INNER JOIN criteria cr ON cr.id=ac.criterion_id
        LEFT JOIN student_assessments stas ON stas.team_id=t.id AND stas.student_from=st.student_id AND stas.student_to=st2.student_id
        LEFT JOIN assessment_responses ares ON ares.student_assessment_id=stas.id and ares.criterion_id=ac.criterion_id
        LEFT JOIN (SELECT criterion_id, MIN(points) as min_points,
                                                   MAX(points) as max_points FROM criterion_levels group by criterion_id) as min_levels
        ON min_levels.criterion_id=ac.criterion_id
    SQL
  end

  down do
    drop_view?(:assessments_results_raw)
  end
end
