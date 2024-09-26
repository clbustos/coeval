class Course < Sequel::Model
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
end