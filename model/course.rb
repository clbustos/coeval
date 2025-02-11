class Course < Sequel::Model
  # This is analog to ResponsePivot of Team
  # but have criteria per assessment
  class ResponsePivot
    attr_reader :pivot
    attr_reader :criteria
    attr_reader :student_total

    def initialize(course, criteria, pivot)
      @course=course
      @criteria=criteria
      @pivot=pivot
      @student_total=calculate_student_total
    end
    # The total should be calculated on the mean
    # of the grading system. If the system are non-compatible
    # the result could be bogus
    def calculate_student_total
      gs_hash=@course.assessments.inject({}) {|ac,assessment|
        ac[assessment[:id]]=Coeval::GradingSystem.new(assessment)
        ac
      }

      @pivot.inject({}) do |ac,v|
        student_id=v[0]
        # v[1] had all information, nested
        k=0
        total=0
        v[1].each do |assessment_id, assessment_data|
          assessment_data.each do |criterion_id, value|
            if not value.nil?
              k=k+1
              total=total+gs_hash[assessment_id].grade(value)
            end
          end
        end
        if k>1
          avg=total/k
        else
          avg=nil
        end
        ac[student_id]=avg
        ac
      end
    end

    def each_criterion_id
      @criteria.each do |row|
        yield row[:criterion_id]
      end
    end
  end


  def teacher_name
    User[self[:teacher_id]].name
  end
  def institution_name
    Institution[self[:institution_id]].name
  end
  def assistant_teachers
    User.where(id: AssistantTeacher.where(:course_id=>self[:id]).map(:teacher_id)  )
  end

  def update_assistant_teachers(teachers_to_add)
    teachers_to_add||=[]
    teachers_to_add=teachers_to_add.map {|v| v.to_i}
    current_teachers=AssistantTeacher.where(course_id:self[:id]).map(:teacher_id)
    #$log.info(current_teachers)
    #$log.info(teachers_to_add)
    to_add = teachers_to_add - current_teachers
    to_delete = current_teachers - teachers_to_add
    $db.transaction do
      to_add.each do |teacher_id|
        AssistantTeacher.insert(course_id:self[:id], teacher_id:teacher_id)
      end
      to_delete.each do |teacher_id|
        AssistantTeacher.where(course_id:self[:id], teacher_id:teacher_id).delete
      end
    end
    true

  end
  def students
    User.where(id:StudentCourse.where(:course_id=>self[:id]).map{|v|v[:student_id]})
  end
  def students_groups
    res=$db["SELECT sc.student_id, a.id as assessment_id, t.id as team_id FROM
student_courses sc INNER JOIN
assessments as a ON sc.course_id=a.course_id INNER JOIN
teams as t  ON t.assessment_id=a.id INNER JOIN
student_teams as st ON t.id=st.team_id AND sc.student_id=st.student_id
 WHERE a.course_id=?", self[:id]]
    out={}
    res.each do |row|
      student_id=row[:student_id]
      if not out.key?(student_id)
        out[student_id]=[]
      end
      out[student_id].push(row)
    end
    out
  end
  def assessments
    Assessment.where(:course_id=>self[:id])
  end

  def response_detail
    $db["SELECT assessment_id, student_to as student_id, criterion_id, COUNT(DISTINCT(student_from)) as n_students,
    COUNT(DISTINCT(ass_id)) as n_responses,
AVG(response_value-min_points)/(max_points-min_points) AS response_avg_partial,
AVG(CASE
        WHEN response_value IS NULL THEN 0
        ELSE (response_value-min_points)/(max_points-min_points)
    END) AS response_avg
    FROM assessments_results_raw AS arr
    INNER JOIN assessments AS a ON arr.assessment_id=a.id
    AND criterion_type!='open_ended' WHERE a.course_id=?  GROUP BY assessment_id, student_to, criterion_id
    ORDER BY assessment_id, student_to, criterion_id", self[:id]]
  end

  def response_pivot(type=:response_avg_partial)

    criteria=$db["SELECT assessment_id, a.name as assessment_name, criterion_id, c.name as criterion_name, criterion_order
FROM assessments as a
INNER JOIN assessment_criteria ac ON ac.assessment_id=a.id
INNER JOIN criteria c ON c.id=ac.criterion_id
WHERE
a.course_id=? AND criterion_type!='open_ended' group by assessment_id, criterion_id
ORDER BY assessment_id, criterion_id
" , self[:id]]

    rs=response_detail
    pivot=rs.inject({}) do |ac,v|
      student_id=v[:student_id]
      if not ac[student_id]
        ac[student_id]={}
        criteria.each do |row|
          ac[student_id][row[:assessment_id]]||={}
          ac[student_id][row[:assessment_id]][row[:criterion_id]]=nil
        end
      end

      ac[student_id][v[:assessment_id]][v[:criterion_id]]=v[type]
      ac
    end
    rp=ResponsePivot.new(self,criteria, pivot)
    rp
  end



end