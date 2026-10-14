# Coeval
# https://github.com/clbustos/coeval
# Copyright (c) 2023, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information


# @!group Courses


get '/courses' do
  halt 403 unless (auth_to('course_view'))

  @courses=Course.order(:active, :name)
  @course_status=params['course_status']
  @course_status||="only_active"
  if @course_status=='only_active'
    @courses=@courses.where(:active=>true)
  elsif @course_status=='only_inactive'
    @courses=@courses.where(:active=>false)
  else
    @courses=@courses
  end
  haml :courses, escape_html: false
end
get '/course/new' do
  halt 403 unless auth_to('course_admin')

  @course=Course.new
  @course.id="new"
  @course.active=true
  @institutions=Institution.order(:name)
  @teachers=User.where(role_id:"teacher").order(:name)
  @lead_teachers=User.lead_teachers
  @assistant_teachers=User.assistant_teachers
  @current_assistant_teachers_id={}
  #$log.info(@lead_teachers)

  haml "courses/edit".to_sym, escape_html: false
end
get '/course/:id' do |id|
  halt 403 unless (auth_to('course_view') or auth_to('assessment_evaluate'))

  @course=Course[id]
  raise Coeval::NoCourseIdError, id unless @course
  assigned_as_assistant=AssistantTeacher[course_id:@course[:id], teacher_id:session['user_id']]
  lead_teacher=@course[:teacher_id].to_i==session['user_id'].to_i
  system_administrator=User[session['user_id']][:role_id]=='administrator'
  student_access=auth_to('assessment_evaluate') && !auth_to('course_view')
  halt 403 unless system_administrator || lead_teacher || assigned_as_assistant || student_access
  @assistant_course_access=!assigned_as_assistant.nil? && !lead_teacher
  @assistant_course_monitor=@assistant_course_access && auth_to('course_assistant_monitor')
  @course_management_access=auth_to('course_admin') && !@assistant_course_access
  @assessment_management_access=auth_to('assessment_admin') && !@assistant_course_access
  if @assistant_course_access
    halt 403 unless @course[:active]
  end
  @course_assessments=Assessment.where(course_id:id).order(:name).all
  @assessments=@course_assessments.to_h {|assessment| [assessment[:id], assessment[:name]]}
  @students = @course.students
  @teams=Team.where(assessment_id: @assessments.keys).as_hash(:id, :name)
  @teams_by_assessment=@course_assessments.to_h do |assessment|
    teams=Team.where(assessment_id:assessment[:id])
    teams=teams.where(teacher_id:session['user_id']) if @assistant_course_access && !@assistant_course_monitor
    teams=teams.order(:name).map do |team|
      {
        team:team,
        teacher:User[team[:teacher_id]],
        members:team.users.order(:name).all
      }
    end
    [assessment[:id], teams]
  end
  @current_assistant_teachers=@course.assistant_teachers
  @student_search=params['student_search'].to_s.strip
  if auth_to('course_admin') and @student_search.length>0
    current_student_ids=@students.map(:id)
    @student_search_results=User.where(role_id:"student")
                                .where(Sequel.ilike(:name, "%#{@student_search}%"))
                                .exclude(id:current_student_ids)
                                .order(:name)
                                .limit(20)
  else
    @student_search_results=[]
  end
  #$log.info(@current_assistant_teachers)
  #$log.info(@assessments)
  #$log.info(@teams)

  haml "courses/view".to_sym, escape_html: false

end

post '/course/:id/student_courses' do |id|
  halt 403 unless auth_to('course_admin')
  @course=Course[id]
  raise Coeval::NoCourseIdError, id unless @course
  user=User[params['user_id']]
  raise Coeval::NoUserIdError, params['user_id'] unless user

  StudentCourse.find_or_create(course_id:@course[:id], student_id:user[:id])
  add_message(t(:Student_added_to_course, student_name:user[:name], course_name:@course[:name]))
  redirect url("/course/#{@course[:id]}")
end

get '/course/:id/assessments' do |id|
  halt 403 unless (auth_to('course_view') or auth_to('assessment_view'))
  @course=Course[id]
  raise Coeval::NoCourseIdError, id unless @course

  @assessments=Assessment.where(course_id:@course[:id]).order(:name)
  haml "courses/assessments".to_sym, escape_html: false
end

get '/course/:id/assessment/new' do |id|
  halt 403 unless auth_to('assessment_admin')
  @course=Course[id]
  raise Coeval::NoCourseIdError, id unless @course

  haml 'courses/assessment_new'.to_sym, escape_html: false
end

get '/course/:id/excel' do |id|
  halt 403 unless auth_to('course_admin')
  @course=Course[id]
  raise Coeval::NoCourseIdError, id unless @course

  haml 'courses/excel'.to_sym, escape_html: false
end

post '/course/:id/assessments' do |id|
  halt 403 unless auth_to('assessment_admin')
  @course=Course[id]
  raise Coeval::NoCourseIdError, id unless @course

  name=params['name'].to_s.strip
  if name.empty?
    add_message(t(:Assessment_without_name), :error)
    redirect back
  end

  now=Time.now
  assessment=Assessment.create(
    course_id:@course[:id],
    active:!params['active'].nil?,
    name:name,
    description:params['description'],
    start_time_evaluation:now,
    end_time_evaluation:now + (60*60*24*30),
    start_time_feedback:now,
    end_time_feedback:now + (60*60*24*60),
    grade_system:params['grade_system'].to_s.strip.empty? ? 'chilean' : params['grade_system'].to_s.strip,
    grade_parameter_1:params['grade_parameter_1'].to_s.strip.empty? ? 60 : params['grade_parameter_1'].to_i,
    grade_parameter_2:params['grade_parameter_2'].to_s.strip.empty? ? nil : params['grade_parameter_2'].to_i
  )
  add_message(t(:Assessment_created, assessment_name:assessment[:name]))
  redirect url("/assessment/#{assessment[:id]}")
end


get '/course/:id/edit' do |id|
  halt 403 unless auth_to('course_admin')

  @course=Course[id]

  @institutions=Institution.order(:name)
  @teachers=User.where(role_id:"teacher").order(:name)
  @lead_teachers=User.lead_teachers
  @assistant_teachers=User.assistant_teachers

  @current_assistant_teachers_id=@course.assistant_teachers.map(:id)
  #$log.info(@current_assistant_teachers_id)
  haml "courses/edit".to_sym, escape_html: false
end




post '/course/:id/edit' do |id|
  halt 403 unless auth_to('course_admin')
  if params['name'].length>0
    if id=='new'
      id=Course.insert(name:params["name"].strip,
                            description:params["description"],
                            institution_id:params['institution'],
                            teacher_id:params['teacher'],
                            active:!params["active"].nil?)
      @course=Course[id]
    else
      @course=Course[id]

      raise Coeval::NoCourseIdError, id unless @course

      @course.update(name:params["name"].strip,
                     description:params["description"],
                     active:!params["active"].nil?,
                     institution_id:params['institution'],
                     teacher_id:params['teacher']
                     )
    end
    if params.has_key? 'assistant_teacher'
      current_assistant_teachers=params['assistant_teacher'].keys
    else
      current_assistant_teachers=nil
    end
    @course.update_assistant_teachers(current_assistant_teachers)



  end
  redirect url("course/#{id}")


end
get '/course/:id/response_detail' do |id|
  halt_unless_auth('course_admin')
  @course=Course[id]
  @crp=@course.response_pivot
  @students=@course.students
  @gs_hash=@course.assessments.inject({}) {|ac,assessment|
    ac[assessment[:id]]=Coeval::GradingSystem.new(assessment)
    ac
  }
  haml "courses/response_detail".to_sym, escape_html: false
end

get '/course/:id/response_detail_excel' do |id|
  require 'caxlsx'
  halt_unless_auth('course_admin')
  @course=Course[id]
  @crp=@course.response_pivot
  @students=@course.students
  @gs_hash=@course.assessments.inject({}) {|ac,assessment|
    ac[assessment[:id]]=Coeval::GradingSystem.new(assessment)
    ac
  }
  package = Axlsx::Package.new
  wb = package.workbook
  blue_cell = wb.styles.add_style  :fg_color => "0000FF", :sz => 14, :alignment => { :horizontal=> :center }
  header_inter=@crp.criteria.map do |criterion|
    "#{criterion[:assessment_name]} - #{criterion[:criterion_name]}"
  end
  header=["student"]+header_inter+[I18n::t(:Total)]

  wb.add_worksheet(:name => t(:Results)) do |sheet|
    sheet.add_row header, :style=> [blue_cell]*header.length
    @crp.pivot.each_pair do |student_id, student_data|
      student_name=@students[student_id][:name]
      grades=@crp.criteria.map do |criterion|
        assessment_id=criterion[:assessment_id]
        criterion_id= criterion[:criterion_id]
        @gs_hash[assessment_id].grade(student_data[assessment_id][criterion_id])
      end

      total=@crp.student_total[student_id]
      sheet.add_row [student_name]+grades+[total]
    end
  end



  headers 'Content-Type' => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  headers 'Content-Disposition' => "attachment; filename=course_results_#{id}.xlsx"
  package.to_stream


end


get '/course/:id/users_batch_edition/excel_export' do |id|
  require 'caxlsx'
  halt_unless_auth('course_admin')
  @course=Course[id]
  halt 404 unless @course
  package = Axlsx::Package.new
  wb = package.workbook
  blue_cell = wb.styles.add_style  :fg_color => "0000FF", :sz => 14, :alignment => { :horizontal=> :center }

  users=@course.students

  #institutions=Institution.to_hash(:id,:name)
  wb.add_worksheet(:name => t(:Users)) do |sheet|
    header = if users.empty?
      ["login", "email", "language", "name", "password", "assessment", "team", "assistant_teacher"]
    else
      ["login", "email", "language", "name"]
    end
    sheet.add_row header, :style=> [blue_cell]*header.length
    users.each do |user|
      row=[user[:login], user[:email], user[:language], user[:name]]
      sheet.add_row row
    end
  end


  headers 'Content-Type' => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  headers 'Content-Disposition' => "attachment; filename=users_course_#{id}.xlsx"
  package.to_stream
end



post '/course/excel_import' do
  halt 403 unless auth_to('course_admin')
  require 'simple_xlsx_reader'
  SimpleXlsxReader.configuration.auto_slurp = true
  archivo=params.delete("file")
  course_id=params['course_id']
  @course=Course[course_id]
  error 404 if !@course
  doc = SimpleXlsxReader.open(archivo["tempfile"])
  sheet=doc.sheets.first
  header=sheet.headers
  id_index       = header.find_index("id")
  id_login       = header.find_index("login")
  id_email       = header.find_index("email")
  id_language    = header.find_index("language")
  id_name        = header.find_index("name")
  id_password     = header.find_index("password")
  id_team        = header.find_index("team")
  id_assessment  = header.find_index("assessment")
  id_assistant_teacher = header.find_index("assistant_teacher")

  result=Result.new

  required_fields={"email"=>id_email, "name"=>id_name}

  missing_fields=required_fields.find_all{|field,value| value.nil?}.map{|x| x[0]}
  if !(missing_fields.length==0 or missing_fields==['id'])
    result.error("Missing fields:#{missing_fields.join(', ')}")
    add_result(result)
    redirect url("/course/#{id}")
  end

  assessment_names=Assessment.where(course_id:course_id).to_hash(:name, :id)
  assistant_teachers=@course.assistant_teachers.to_hash(:login, :id)
  new_students=0
  old_students=0
  $db.transaction(:rollback => :rollback) do
    sheet.data.each do |row|
      email=row[id_email] # Required
      name=row[id_name] # Required

      login=id_login.nil? ? nil: row[id_login]
      user_id=id_index.nil? ? nil : row[id_index]
      team=id_team.nil? ? nil :  row[id_team]
      assessment=id_assessment.nil? ? nil : row[id_assessment]

      language=id_language.nil? ? nil : row[id_language]
      password=id_password.nil? ? nil : row[id_password]
      assistant_teacher = id_assistant_teacher.nil? ? nil: row[id_assistant_teacher]
      next if email.nil?


      login=email if login.nil?



      user_o=nil
      # Login and name should be the same. If not, ok
      if user_id.nil?
        # if we found a user with the same email and login, use it
        if User.where(Sequel.&(email:email, login:login)).count==1
          user_o=User[email:email, login:login]
          old_students+=1
          # if we found any user with the same email, login or name
        elsif User.where {Sequel.or(email:email, login:login, name:name)}.count>0
          result.error("User already exists:#{login}, #{name}, #{email}")
          next
        else
          # There is no user like us. We could create a new one.
          # We need some extra information
          if language.nil? or password.nil?
            result.error("User #{login} doesn't have language nor password")
            next
          end
          user_o=User.create(active:true, email:email, institution_id: @course.institution_id,
                             language:language, login:login, name:name, password:Digest::SHA1.hexdigest(password),
                             role_id:"student")
          new_students+=1
          result.success("User add: #{name}")
        end
      else
        user_o=User[id:user_id]
      end
      StudentCourse.find_or_create(course_id:course_id, student_id:user_o[:id])

      if assessment
        assessment_id=assessment_names[assessment] || Assessment.find_or_create(active:1, name:assessment,
                                                                                course_id: course_id,
                                                                                grade_system: 'chilean')[:id]
        result.success("Assessment add: #{assessment}")
        team_names=Team.where(assessment_id:assessment_id).to_hash(:name,:id)
        if team

          team_teacher_id=assistant_teachers[assistant_teacher] || @course.teacher_id

          team_id=team_names[team] || Team.find_or_create(name:team, assessment_id:assessment_id, teacher_id:team_teacher_id)[:id]
          StudentTeam.find_or_create(team_id:team_id, student_id:user_o[:id])
          result.success("Student #{name} added to team #{team} ")

        end

      end



    end
  end
  result.info(::I18n::t(:Report_excel_import_course, new_students:new_students, old_students:old_students ))


  add_result(result)
  redirect back

end



# @!endgroup
