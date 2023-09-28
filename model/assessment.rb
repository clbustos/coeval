require 'sequel'
require_relative 'models'
class Assessment < Sequel::Model
  def course
    Course[self[:course_id]]
  end
  def course_name
    course[:name]
  end
  def teacher
    User[course[:teacher_id]]
  end
  def teams
    Team.where(:assessment_id=>self[:id])
  end
  # For each team, retrieve the completion rate of their members
  def teams_completation_rate
    $db["SELECT st.team_id, t.name as team_name, COUNT(DISTINCT(student_id)) as n_students,
SUM(CASE WHEN complete IS NULL THEN 0 ELSE 1 END) as n_responses FROM teams t INNER JOIN student_teams st on t.id=st.team_id
LEFT JOIN student_assessments sa ON sa.student_from=st.student_id and sa.team_id=t.id
WHERE assessment_id=? GROUP BY team_id", self[:id]].to_hash(:team_id)
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
