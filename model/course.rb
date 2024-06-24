class Course < Sequel::Model
  def teacher_name
    User[self[:teacher_id]].name
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
end