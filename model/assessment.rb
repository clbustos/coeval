require 'sequel'
require_relative 'models'
class Assessment < Sequel::Model
  def course
    Course[self[:course_id]]
  end
  def course_name
    course[:name]
  end

  def delete_complete
    # First, get teams and students
    teams_id=teams.map {|team| team[:id]}
    students_id=StudentTeam.where(team_id: teams_id).map {|st| st[:student_id]}
    sta=StudentAssessment.where(team_id: teams_id)
    AssessmentResponse.where(student_assessment_id:sta.map {|stai|stai[:student_assessment_id]}).delete
    AssessmentCriterion.where(assessment_id:self[:id]).delete
    sta.delete
    StudentAssessment.where(team_id: teams_id).delete
    StudentTeam.where(team_id: teams_id).delete
    Team.where(id:teams_id).delete
    self.delete
    return true


  end
  def student_assessments
    StudentAssessment.where(team_id: teams.map {|team| team[:id]})
  end
  def criteria_hash
    @criteria_hash||=      AssessmentCriterion.where(assessment_id:self[:id]).to_hash(:criterion_id, :criterion_order)

  end
  def teacher
    User[course[:teacher_id]]
  end
  def teams
    Team.where(:assessment_id=>self[:id])
  end
  def moment_to_evaluate?
    now=Time.now
    correct_start=self[:start_time_evaluation].nil? || self[:start_time_evaluation]<=now
    correct_end=self[:end_time_evaluation].nil? || self[:end_time_evaluation]>=now

    correct_start and correct_end
  end
  def feedback_moment?
    now=Time.now
    correct_start=self[:start_time_feedback].nil? || self[:start_time_feedback]<=now
    correct_end=self[:end_time_feedback].nil? || self[:end_time_feedback]>=now

    correct_start and correct_end
  end




  def open_ended_responses(extra_criteria= { })

    where_cond={criterion_type:'open_ended', assessment_id:self[:id]}.merge(extra_criteria)

    $db[:assessments_results_raw].where(where_cond)
  end

  def response_detail_student
    $db["SELECT MAX(team_id) as team_id, student_id, SUM(n_responses) AS n_responses_total,
AVG(perc_complete) as avg_perc_complete,
AVG(response_avg_partial) AS response_avg_partial_total,
AVG(response_avg) AS response_avg_total

 FROM (SELECT student_to as student_id, team_id, criterion_id, COUNT(DISTINCT(student_from)) as n_students,
COUNT(DISTINCT(ass_id)) as n_responses,
AVG(CASE WHEN saved = 1 THEN 1 ELSE 0 END)*100 AS perc_complete,
AVG(response_value-min_points)/(max_points-min_points) AS response_avg_partial,
AVG(CASE
        WHEN response_value IS NULL THEN 0
        ELSE (response_value-min_points)/(max_points-min_points)
    END) AS response_avg

FROM assessments_results_raw
WHERE assessment_id=? AND criterion_type!='open_ended' GROUP BY team_id, student_to, criterion_id
ORDER BY student_to, criterion_id) AS t GROUP BY student_id ", self[:id]]
  end


  # For each team, retrieve the completion rate of their members
  def teams_completation_rate
    $db["SELECT team_id, t_name as team_name, COUNT(DISTINCT(student_from)) as n_students,
COUNT(DISTINCT(ass_id)) as n_responses,
AVG(CASE WHEN saved = 1 THEN 1 ELSE 0 END)*100 AS perc_complete,
AVG(CASE
        WHEN criterion_type = 'open_ended' THEN NULL
        ELSE (response_value-min_points)/(max_points-min_points)
    END) AS response_avg_partial,
AVG(CASE
        WHEN criterion_type = 'open_ended' THEN NULL
        WHEN response_value IS NULL THEN 0
        ELSE (response_value-min_points)/(max_points-min_points)
    END) AS response_avg

FROM assessments_results_raw
WHERE assessment_id=? GROUP BY team_id order by t_name", self[:id]].to_hash(:team_id)



  end
  # Retrieves the list of other students of a team
  # of a given student
  def are_student_from_same_team?(student_from, student_to)
    res=$db['SELECT count(DISTINCT(student_id)) as st_n,
COUNT(DISTINCT(team_id)) as t_n
FROM student_teams st INNER JOIN teams t ON st.team_id=t.id
WHERE student_id IN (?,?) and assessment_id=?', student_from[:id],
        student_to[:id], self[:id]].first
    res[:t_n]==1 and ((student_from[:id]==student_to[:id] and res[:st_n]==1 ) or
      (student_from[:id]!=student_to[:id] and res[:st_n]==2))
  end

  def complete_report

  end


  # Retrieves the complete structure of criteria
  # and levels
  # To maintain order, I will retrieve as an array
  def criteria_structure
    out=$db["SELECT criterion_order, c.name as criterion_name,
c.criterion_type as criterion_type, ac.criterion_id, points, description as level_description FROM criteria c INNER JOIN
 assessment_criteria ac ON ac.criterion_id=c.id
LEFT JOIN criterion_levels cl ON ac.criterion_id=cl.criterion_id
WHERE assessment_id=? ORDER BY criterion_order, points DESC", self[:id]].all
    out2=out.inject({}) do |ac,v|
      ac[v[:criterion_order]]||={criterion_order: v[:criterion_order],
                                 criterion_id: v[:criterion_id],
                                 criterion_name: v[:criterion_name],
                                 criterion_type: v[:criterion_type],
                                 levels:{}
      }

      ac[v[:criterion_order]][:levels][v[:points]]=v unless v[:points].nil?
      ac
    end
    out2.sort_by {|k,v| v[:criterion_order]}.map do |pair|
      v=pair[1]
      #$log.info(v[:levels])
      if v[:levels].length>0
        levels_o=v[:levels].sort_by {|k,v| -k}.map { |pair2|
          p2=pair2[1]
          {points:p2[:points], description:p2[:level_description]}
        }
        v[:levels]=levels_o
      end
      v
    end
  end



end
