class Team < Sequel::Model
  self.unrestrict_primary_key


  def members_completation_rate
    $db["SELECT st.student_id, u.name as student_name,
SUM(CASE WHEN complete IS NULL THEN 0 ELSE 1 END) as n_responses
FROM users as u
INNER JOIN student_teams st on u.id=st.student_id
LEFT JOIN student_assessments sa ON sa.student_from=st.student_id and sa.team_id=st.team_id
WHERE st.team_id=? GROUP BY st.student_id",self[:id]].to_hash(:student_id)
  end

  def assessment
    @assessment||=Assessment[self[:assessment_id]]
    @assessment
  end
  def assessment_name
    self.assessment[:name]
  end
  # Retrieve the team ID for a specific student (user) and assessment combination.
  #
  # @param user_id [Integer] ID of the student.
  # @param assessment_id [Integer] ID of the assessment.
  # @return [Integer, nil] The ID of the team or nil if no matching record is found.

  def self.team_id_of_student_assessment(user_id, assessment_id)
    $db['SELECT t.id as team_id FROM  teams t INNER JOIN student_teams st  ON t.id=st.team_id
WHERE student_id=? and assessment_id=? ', user_id, assessment_id].get(:team_id)
  end


end