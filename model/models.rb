require 'sequel'
require_relative 'group'
require_relative 'user'
#require_relative 'messages'

Sequel.inflections do |inflect|
  inflect.irregular 'criterion','criteria'
end


class Criterion < Sequel::Model
  self.unrestrict_primary_key
end

class CriterionLevel < Sequel::Model
  self.unrestrict_primary_key

end


class User < Sequel::Model

end
class Course < Sequel::Model
  def teacher_name
    User[self[:teacher_id]].name
  end
  def students
    User.where(id:StudentCourse.where(:course_id=>self[:id]).map{|v|v[:student_id]})
  end
  def assessments
    Assessment.where(:course_id=>self[:id])
  end
end

class StudentCourse < Sequel::Model
  self.unrestrict_primary_key

end
class Institution < Sequel::Model

end
class Group < Sequel::Model

end

class AssessmentCriterion < Sequel::Model
  self.unrestrict_primary_key
end

class Team < Sequel::Model
  self.unrestrict_primary_key

  def self.team_id_of_student_assessment(user_id, assessment_id)
    $db['SELECT t.id as team_id FROM  teams t INNER JOIN student_teams st  ON t.id=st.team_id
WHERE student_id=? and assessment_id=? ', user_id, assessment_id].get(:team_id)
  end
end

class StudentAssessment < Sequel::Model

end

class AssessmentResponse < Sequel::Model
  self.unrestrict_primary_key
end

class StudentTeam < Sequel::Model
  self.unrestrict_primary_key
end