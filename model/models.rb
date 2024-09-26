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


class StudentAssessment < Sequel::Model

end

class AssessmentResponse < Sequel::Model
  self.unrestrict_primary_key
end

class StudentTeam < Sequel::Model
  self.unrestrict_primary_key
end

class AssistantTeacher < Sequel::Model
  self.unrestrict_primary_key
end