class Team < Sequel::Model
  class ResponsePivot
    attr_reader :pivot
    attr_reader :criteria
    attr_reader :student_total

    def initialize(criteria, pivot)
      @criteria=criteria
      @pivot=pivot
      @student_total=calculate_student_total
    end
    def calculate_student_total
      k=@criteria.count
      @pivot.inject({}) do |ac,v|
        student_id=v[0]

        res=v[1].inject(0) {|ac2,v2|
          if v2[1].nil?
            0
          else
            ac2+v2[1]

          end


        }/k
        ac[student_id]=res
        ac
      end
    end

    def each_criterion_id
      @criteria.each do |row|
        yield row[:criterion_id]

      end
    end
  end
  self.unrestrict_primary_key

  def users
    students_id=$db["SELECT student_id FROM student_teams WHERE team_id=?", self[:id]].map(:student_id)
    User.where(id:students_id)
  end
  def response_detail
    $db["SELECT student_to as student_id, criterion_id, COUNT(DISTINCT(student_from)) as n_students,
COUNT(DISTINCT(ass_id)) as n_responses,
AVG(CASE WHEN saved = 1 THEN 1 ELSE 0 END)*100 AS perc_complete,
AVG(response_value-min_points)/(max_points-min_points) AS response_avg_partial,
AVG(CASE
        WHEN response_value IS NULL THEN 0
        ELSE (response_value-min_points)/(max_points-min_points)
    END) AS response_avg

FROM assessments_results_raw
WHERE team_id=? AND criterion_type!='open_ended' GROUP BY student_to, criterion_id
ORDER BY student_to, criterion_id", self[:id]]
  end

  # provide a pivot table, to fast visualize the result of different students
  #

  def response_pivot(type=:response_avg)

    criteria=$db["SELECT criterion_id, c.name as criterion_name FROM assessment_criteria ac
INNER JOIN criteria c ON c.id=ac.criterion_id WHERE ac.assessment_id=? AND
criterion_type!='open_ended' ORDER BY ac.criterion_order", self[:assessment_id]]
    criteria_hash=criteria.inject({}) {|ac,v|  ac[v[:criterion_id]]=0;ac }
    rs=response_detail

    pivot=rs.inject({}) do |ac,v|
      student_id=v[:student_id]
      ac[student_id]= criteria_hash.dup unless ac[student_id]
      ac[student_id][v[:criterion_id]]=v[type]
      ac
    end
    rp=ResponsePivot.new(criteria, pivot)
    rp
  end

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