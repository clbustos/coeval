# encoding: UTF-8
require 'logger'
require 'i18n'
require 'dotenv'
require 'sequel'

require 'digest/sha1'

if !$test_mode
  Dotenv.load("./.env")
end

log_db=Logger.new("log/installer_sql.log")
db=Sequel.connect(ENV['DATABASE_URL'], :encoding => 'utf8',:reconnect=>true)
db.loggers << log_db


db.transaction do
  db.create_table? :roles do
    String :id, :size => 50, :primary_key => true
    String :description
  end

  db.create_table? :institutions do
    primary_key :id
    String :name
  end

  db.create_table? :users do
    primary_key :id
    String :registration_code, :size=>255
    String :login, :size=>255
    String :name, :text=>true
    String :email, :size=>255, :unique=>true, :null=>true
    String :password, :size=>255
    String :language, :size=>3
    String :token_password, :size=>255
    DateTime :token_datetime
    foreign_key :institution_id, :institutions
    foreign_key :role_id, :roles, :type => String, :size => 50, :null => false, :key => [:id]
    TrueClass :active, :default=>true, :null=>false
  end

  db.create_table? :groups do
    primary_key :id
    foreign_key :group_administrator, :users, :null => false, :key => [:id]
    String :description, :text => true
    String :name, :size => 255, :null => false
  end


end
db.transaction do
  db.create_join_table?(:user_id => :users, :group_id=> :groups)
end
db.transaction do
  db.create_table? :authorizations do
    String :id, :size => 50, :primary_key => true
    String :description, :size => 255
  end
end
db.transaction do
  db.create_table? :authorizations_roles do
    foreign_key :authorization_id, :authorizations, :type => String, :size => 50, :null => false, :key => [:id]
    foreign_key :role_id, :roles, :type => String, :size => 50, :null => false, :key => [:id]

    primary_key [:authorization_id, :role_id]

    index [:role_id]
  end


end


db.transaction do
  db.create_table? :criteria do
    String :id, :size=>50, :primary_key => true
    String :name, :null=>false
    String :criterion_type
  end

  db.create_table? :criterion_levels do
    Integer :points, :null=>false
    String :description, :text => true
    String :criterion_id, :size=>50, :null=>false
    foreign_key [:criterion_id], :criteria, :null => false, :name=> 'fk_cl_criterion_id'
    primary_key [:criterion_id, :points], :name=> :criterion_levels_pk

  end





  db.create_table? :courses do
    primary_key :id
    String :name,:null=>false
    String :description, :text => true
    foreign_key :institution_id, :institutions, :null=>false
    TrueClass :active, :default=>true, :null=>false
    foreign_key :teacher_id, :users, :null=>false, :key=>[:id]

  end

  db.create_table? :assessments do
    primary_key :id
    foreign_key :course_id, :courses, :null=>false
    TrueClass :active, :default=>true, :null=>false
    String :name, :null=>false
    String :description, :text => true
    DateTime :start_time_evaluation , :null=>false
    DateTime :end_time_evaluation   , :null=>false
    DateTime :start_time_feedback   , :null=>false
    DateTime :end_time_feedback     , :null=>false

    String :grade_system, :size=>64, :null=>true
    Integer :grade_parameter_1, :null=>true
    Integer :grade_parameter_2, :null=>true
  end

  db.create_table? :assessment_criteria do
    String :criterion_id, :size=>50, :null=>false
    foreign_key [:criterion_id], :criteria, :null => false, :name=> 'fk_as_criterion_id'
    foreign_key :assessment_id, :assessments
    Integer :criterion_order
    primary_key [:criterion_id, :assessment_id]
  end

  db.create_table? :student_courses do
    foreign_key :course_id, :courses, :null=>false
    foreign_key :student_id, :users, :null=>false, :key=>[:id]
    primary_key [:course_id, :student_id]

  end

  # Cada team está asociado a una evaluación específica.

  db.create_table? :teams do
    primary_key :id
    String :name, :text=>true
    foreign_key :assessment_id, :assessments, :null => false, :key => [:id]
    foreign_key :teacher_id, :users, :null => false, :key => [:id]
  end

  db.create_table? :student_teams do
    foreign_key :team_id, :teams, :null => false, :key => [:id]
    foreign_key :student_id, :users, :null => false, :key => [:id]
    primary_key [:team_id, :student_id]
  end
end


  db.transaction do
    db.create_table? :student_assessments do
      primary_key :id
      foreign_key :team_id, :teams, :null => false, :key => [:id]
      foreign_key :student_from, :users, :null => false, :key => [:id]
      foreign_key :student_to, :users, :null => false, :key => [:id]
      TrueClass :complete, :default => false, :null => false
      TrueClass :saved, :default => false, :null => false
      DateTime :sent
      index [:team_id, :student_from, :student_to], :unique=>true
    end
    db.create_table? :assessment_responses do
      Integer :student_assessment_id;
      String :criterion_id, :size=>50
      foreign_key [:criterion_id], :criteria, :null => false, :name=> 'fk_sc_criterion_id'
      foreign_key [:student_assessment_id], :student_assessments, :null => false, :key => [:id]
      String :response_value, :text=>true
      TrueClass :omitted, :default => false, :null => false
      primary_key [:student_assessment_id, :criterion_id ], :name=> :students_criteria_pk
    end


  end

db.transaction do
  db.create_table? :messages do
    # Mïnimo número de references rtr para revisión de references
    primary_key :id
    foreign_key :user_from, :users, :null=>false, :key=>[:id]
    foreign_key :user_to, :users, :null=>false, :key=>[:id]
    foreign_key :reply_to,   :messages, :null=>true, :key=>[:id]
    DateTime :time
    String :subject
    String :text, :text=>true
    Bool :viewed
    index [:user_from]
    index [:user_to]
  end

end

db.transaction do
  db.create_or_replace_view(:assessments_results_raw, "
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
  ON min_levels.criterion_id=ac.criterion_id")
end

db.transaction do
  db.create_table? :assistant_teachers do
    foreign_key :course_id, :courses, :null=>false
    foreign_key :teacher_id, :users, :null=>false, :key=>[:id]
    primary_key [:course_id, :teacher_id]

  end
end

