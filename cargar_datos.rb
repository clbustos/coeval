# encoding: UTF-8
require "bundler/setup"
require 'logger'
require 'i18n'
require 'dotenv'
require 'sequel'
require 'rubyXL'
require 'digest/sha1'
require 'rubyXL/convenience_methods/worksheet'



if !$test_mode
  Dotenv.load("./.env")
end

log_db=Logger.new("log/installer_sql.log")
db=Sequel.connect(ENV['DATABASE_URL'], :encoding => 'utf8',:reconnect=>true)
db.loggers << log_db

require_relative 'model/models'
require_relative 'model/assessment'

require_relative 'utils.rb'

def get_id_user_by_login(db,login)
  user=db[:users][:login=>login]
  user ? user[:id] :nil
end


def insert_group_user_if_not_exists(db, group_id, user_id)
  if db[:groups_users].where(:group_id => group_id, :user_id => user_id).count==0
    db[:groups_users].insert(:group_id => group_id, :user_id => user_id)
  end
end
def create_authorizations(db)
  authorizations = [
    'dashboard_view',
    'course_view',
    'course_admin',
    'assessment_view',
    'assessment_admin',
    'assessment_evaluate',
    'group_admin',
    'group_view',
    'message_edit',
    'message_view',
    'user_admin',
    'message_view',
    'role_admin',
    'role_view'
  ]
  authorizations.each do |auth|
    db[:authorizations].insert(:id => auth) unless db[:authorizations][id:auth]
    #puts(db[:authorizations_roles].where(:authorization_id => auth, :role_id => 'administrator').count)
    db[:authorizations_roles].insert(:authorization_id => auth, :role_id => 'administrator') unless db[:authorizations_roles].where(:authorization_id => auth, :role_id => 'administrator').count>0
  end

end

def create_roles(db)
  db[:roles].insert(:id => 'administrator', :description => 'App administrator') unless db[:roles][id:'administrator']
  db[:roles].insert(:id => 'teacher', :description => 'Teacher') unless db[:roles][id:'teacher']
  db[:roles].insert(:id => 'student', :description => 'Student') unless db[:roles][id:'student']
  db[:roles].insert(:id => 'guest', :description => 'Guest') unless db[:roles][id:'guest']
end
udec_id=nil
db.transaction do

  inst_udec=Institution.find_or_create(name:'Universidad de Concepción')
  udec_id=inst_udec[:id]
  create_roles(db)
  create_authorizations(db)



  teacher_permits = ['dashboard_view','course_view', 'course_admin', 'assessment_view', 'assessment_admin']
  teacher_permits.each do |auth|
    db[:authorizations_roles].replace(:authorization_id => auth, :role_id => 'teacher') if db[:authorizations_roles].where(:authorization_id => auth, :role_id => 'teacher').count==0
  end

  student_permits = ['dashboard_view','assessment_evaluate']
  student_permits.each do |auth|
    db[:authorizations_roles].replace(:authorization_id => auth, :role_id => 'student') if db[:authorizations_roles].where(:authorization_id => auth, :role_id => 'student').count==0
  end

  guest_permits = ['dashboard_view','course_view',  'assessment_view']
  guest_permits.each do |auth|
    db[:authorizations_roles].replace(:authorization_id => auth, :role_id => 'guest') if db[:authorizations_roles].where(:authorization_id => auth, :role_id => 'guest').count==0
  end




  id_admin = get_id_user_by_login(db, 'admin')
  id_admin ||= db[:users].insert(:login => 'admin',
                                 :name => 'Admin',
                                 :password => Digest::SHA1.hexdigest('admin'),
                                 :role_id => 'administrator', :active => 1, :language => "es",
                                 :email=>'coeval@test.com',
                                 :institution_id=>udec_id)





  if db[:groups][id:1]
    group_id = 1
  else
    group_id = db[:groups].insert(:id=>1,:group_administrator => id_admin,
                                  :description => "First group, just for demostration",
                                  :name => "demo group")
  end
  insert_group_user_if_not_exists(db,group_id, id_admin)

end



db.transaction do



  curso=Course.find_or_create(name:'Metodología de la Investigación',
                              :teacher_id=>User[:login=>'admin'][:id],
                              :institution_id=>udec_id)
  # curso= Course[name:'Metodología de la Investigación']
  # if not curso
  #   curso=Course.create(name:'Metodología de la Investigación', :teacher_id=>User[:login=>'admin'][:id])
  #
  # end
  puts(curso[:id])

  # evaluacion= Assessment[name:'Coevaluación 1']
  # if not evaluacion
    evaluacion=Assessment.find_or_create(name:'Coevaluación 1',
                                 course_id:curso[:id],
                                 active:true)

  #end

  puts(evaluacion[:id])


  book = RubyXL::Parser.parse('criterios.xlsx')
  worksheet = book.worksheets[0] # can use an index or worksheet name
  i=1
  dataframe(worksheet).each do |row|
    cr=Criterion.find_or_create(id:row['criterio_id']) {|a|
       a.name=row['criterio_nombre']
       a.criterion_type=row['criterion_type']
     }
    AssessmentCriterion.find_or_create(:criterion_id=>cr[:id], :assessment_id=>evaluacion[:id], :criterion_order=>i)
    i+=1
  end
  book = RubyXL::Parser.parse('niveles.xlsx')
  worksheet = book.worksheets[0] # can use an index or worksheet name

  dataframe(worksheet).each do |row|
    CriterionLevel.find_or_create(criterion_id:row['criterio_id'], points:row['points']) {|a|
      a.description=row['description']
    }
  end

  book=RubyXL::Parser.parse('curso_grupo_1.xlsx')
  worksheet = book.worksheets[0] # can use an index or worksheet name

  dataframe(worksheet).each do |row|
    student=User.find_or_create(:login=>row['email'].to_s.strip) {|a|
      a.registration_code=row['matricula'].to_s.strip
      a.name=row['nombre'].strip
      a.login=row['email'].strip
      a.email=row['email'].strip
      a.role_id="student"
      a.language="es"
      a.institution_id=udec_id
      a.password=Digest::SHA1.hexdigest(row['matricula'].to_s.strip)
    }
    student_course=StudentCourse.find_or_create(:course_id=>curso[:id], :student_id=>student[:id])
    puts row['grupo']
    if !(row['grupo'].nil?) and row['grupo'].strip!=""
      team=Team.find_or_create(:assessment_id=>evaluacion[:id], :name=>row['grupo'].strip)
      student_group=StudentTeam.find_or_create(:team_id=>team[:id], :student_id=>student[:id])

    end
  end
end