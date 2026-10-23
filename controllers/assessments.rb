# Coeval
# https://github.com/clbustos/coeval
# Copyright (c) 2023, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information


# @!group Assessments

ASSESSMENT_DATETIME_FIELDS=[:start_time_evaluation, :end_time_evaluation, :start_time_feedback, :end_time_feedback]

def assessment_datetime_values(params)
  require 'time'
  ASSESSMENT_DATETIME_FIELDS.inject({}) do |ac, field|
    field_name=field.to_s
    ac[field]=if !params["#{field_name}_nil"].nil? or params[field_name].to_s.strip.empty?
                nil
              else
                Coeval::TimeZone.parse(params[field_name], @assessment.course.timezone)
              end
    ac
  end
rescue ArgumentError, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
  add_message(t(:Invalid_local_datetime), :error)
  redirect back
end

def valid_assessment_datetime_order?(values)
  fixed_values=ASSESSMENT_DATETIME_FIELDS.map {|field| values[field]}.compact
  fixed_values.each_cons(2).all? {|previous_value, next_value| next_value>=previous_value}
end

def halt_invalid_assessment_datetime_order(values)
  return if valid_assessment_datetime_order?(values)

  add_message(t(:Assessment_datetime_order_error), :error)
  redirect back
end

def excel_percentage_from_proportion(value)
  return '--' if value.nil?

  (value*100.0).to_i
end

def excel_grade(grading_system, value)
  grading_system.grade(value) || '--'
end

def assistant_team_ids_for(assessment, user_id)
  assigned=AssistantTeacher[course_id:assessment[:course_id], teacher_id:user_id]
  return [] unless assigned && assessment.course[:active]

  Team.where(assessment_id:assessment[:id], teacher_id:user_id).map(:id)
end

def assistant_visible_team_ids_for(assessment, user_id)
  return [] unless assistant_can_access_assessment?(assessment, user_id)
  return assessment.teams.map(:id) if auth_to('course_assistant_monitor')

  assistant_team_ids_for(assessment, user_id)
end

def assistant_can_access_assessment?(assessment, user_id)
  !AssistantTeacher[course_id:assessment[:course_id], teacher_id:user_id].nil? && assessment.course[:active]
end

def course_assistant_for_assessment?(assessment, user_id)
  assessment.course[:teacher_id].to_i!=user_id.to_i &&
    !AssistantTeacher[course_id:assessment[:course_id], teacher_id:user_id].nil?
end


get '/assessments' do
  halt 403 unless (auth_to('assessment_view'))

  @assessments=Assessment.order(:course_id, :name)
  unless auth_to('assessment_admin')
    assigned_course_ids=AssistantTeacher.where(teacher_id:session['user_id']).map(:course_id)
    active_course_ids=Course.where(id:assigned_course_ids, active:true).map(:id)
    @assessments=@assessments.where(course_id:active_course_ids)
  end
  @courses_h=Course.order(:active, :name).to_hash(:id, :name)

  haml :assessments, escape_html: false
end

get '/assessment/:id/delete' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])


  haml "assessments/prepare_delete".to_sym, escape_html: false
end

post '/assessment/:id/delete' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  assessment_id=params['assessment_id']
  @assessment=Assessment[assessment_id]
  raise Coeval::NoAssessmentIdError, assessment_id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])

  course_id=@assessment[:course_id]
  $db.transaction(rollback: :reraise) do
    @assessment.delete_complete
  end
  add_message(::I18n::t(:Assessment_deleted))

  redirect url("/course/#{course_id}")
end


get '/assessment/:id' do |id|
  halt 403 unless (auth_to('assessment_view') or auth_to('assessment_evaluate'))
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  @assistant_assessment_access=course_assistant_for_assessment?(@assessment, session['user_id'])
  if @assistant_assessment_access
    halt 403 unless assistant_can_access_assessment?(@assessment, session['user_id'])
  end
  @gs=Coeval::GradingSystem.new(@assessment)
  @teams_summary=@assessment.teams_completation_rate
  if @assistant_assessment_access
    @assistant_assigned_team_ids=assistant_visible_team_ids_for(@assessment, session['user_id'])
    @teams_summary.select! {|team_id, _team_data| @assistant_assigned_team_ids.include?(team_id)}
  end
  if auth_to('assessment_admin')
    @course_students=@assessment.course.students.order(:name)
    @teams_for_assignment=@assessment.teams.order(:name)
    @student_team_ids=$db[:student_teams]
                      .join(:teams, id: :team_id)
                      .where(assessment_id:@assessment[:id])
                      .select(:student_id, :team_id)
                      .all
                      .inject({}) {|ac,row| ac[row[:student_id]]=row[:team_id]; ac}
  end
  haml "assessments/view".to_sym, escape_html: false
end

get '/assessment/:id/preview' do |id|
  halt 403 unless auth_to('assessment_view')
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment

  if course_assistant_for_assessment?(@assessment, session['user_id'])
    halt 403 unless assistant_can_access_assessment?(@assessment, session['user_id'])
  end

  @structure=@assessment.criteria_structure
  haml "assessments/preview".to_sym, escape_html: false
end

get '/assessment/:id/teacher_assignation' do |id|
  halt 403 unless auth_to('assessment_admin')
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])

  @teams=@assessment.teams.order(:name)
  course=@assessment.course
  teacher_ids=[course[:teacher_id]] + course.assistant_teachers.map(:id)
  @teachers=User.where(id:teacher_ids.uniq).order(:name)
  haml 'assessments/teacher_assignation'.to_sym, escape_html: false
end

post '/assessment/:id/teacher_assignation' do |id|
  halt 403 unless auth_to('assessment_admin')
  assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless assessment
  halt 403 if course_assistant_for_assessment?(assessment, session['user_id'])

  team_ids=Array(params['team_ids']).map(&:to_i).uniq
  if team_ids.empty?
    add_message(t(:No_teams_selected), :error)
    redirect url("/assessment/#{assessment[:id]}/teacher_assignation")
  end

  teacher_id=params['teacher_id'].to_i
  course=assessment.course
  allowed_teacher_ids=([course[:teacher_id]] + course.assistant_teachers.map(:id)).map(&:to_i)
  unless allowed_teacher_ids.include?(teacher_id)
    add_message(t(:No_teacher_selected), :error)
    redirect url("/assessment/#{assessment[:id]}/teacher_assignation")
  end

  teams=assessment.teams.where(id:team_ids)
  halt 403 unless teams.count==team_ids.length

  teams.update(teacher_id:teacher_id)
  add_message(t(:Teams_assigned_to_teacher, count:team_ids.length, teacher_name:User[teacher_id][:name]))
  redirect url("/assessment/#{assessment[:id]}/teacher_assignation")
end

post '/assessment/:id/teams' do |id|
  halt 403 unless auth_to('assessment_admin')
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])

  name=params['name'].to_s.strip
  if name.empty?
    add_message(t(:Team_without_name), :error)
    redirect back
  end

  Team.find_or_create(name:name, assessment_id:@assessment[:id]) do |team|
    team.teacher_id=params['teacher_id'].to_s.empty? ? @assessment.course[:teacher_id] : params['teacher_id']
  end
  add_message(t(:Team_created, team_name:name))
  redirect url("/assessment/#{@assessment[:id]}")
end

post '/assessment/:id/student_teams' do |id|
  halt 403 unless auth_to('assessment_admin')
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])
  team=Team[params['team_id']]
  raise Coeval::NoTeamIdError, params['team_id'] unless team
  halt 403 unless team[:assessment_id].to_i==@assessment[:id].to_i

  student_ids=Array(params['student_ids']).map(&:to_i)
  if student_ids.empty?
    add_message(t(:No_students_selected), :error)
    redirect back
  end

  course_student_ids=StudentCourse.where(course_id:@assessment[:course_id], student_id:student_ids).map(:student_id)
  halt 403 unless course_student_ids.length==student_ids.length

  team_ids=@assessment.teams.map(:id)
  $db.transaction do
    StudentTeam.where(team_id:team_ids, student_id:student_ids).delete
    student_ids.each do |student_id|
      StudentTeam.find_or_create(team_id:team[:id], student_id:student_id)
    end
  end
  add_message(t(:Students_assigned_to_team, count:student_ids.length, team_name:team[:name]))
  redirect url("/assessment/#{@assessment[:id]}")
end

get '/assessment/:id/edit' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])
  @criteria_hash=@assessment.criteria_hash
  haml "assessments/edit".to_sym, escape_html: false
end

get '/assessment/:id/export_excel' do |id|
  require 'caxlsx'

  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  assistant_team_ids=assistant_visible_team_ids_for(@assessment, session['user_id'])
  course_assistant=course_assistant_for_assessment?(@assessment, session['user_id'])
  halt 403 unless (auth_to('assessment_admin') && !course_assistant) || (auth_to('assessment_view') && assistant_team_ids.any?)
  @gs=Coeval::GradingSystem.new(@assessment)
  response_details=@assessment.response_detail_student
  response_details=response_details.where(team_id:assistant_team_ids) if course_assistant || !auth_to('assessment_admin')
  rds=response_details.all
  teams=Team.where(:id=>rds.map {|v| v[:team_id]}.uniq).to_hash(:id, :name)
  students=User.where(:id=>rds.map {|v| v[:student_id]}.uniq).to_hash(:id, :name)
  @package = Axlsx::Package.new
  wb = @package.workbook
  @blue_cell = wb.styles.add_style  :fg_color => "0000FF", :sz => 12, :alignment => { :horizontal=> :center }

  wb.add_worksheet(:name => I18n::t("Results")) do |sheet|
    sheet.add_row [I18n::t(:Team), I18n::t(:Student),
                   I18n::t(:Response_count),
                    I18n::t(:Completion),
                   I18n::t(:Average_partial),
                   I18n::t(:Average_total), I18n::t(:Grade_partial),I18n::t(:Grade_total) ],
       :style=>[@blue_cell]*8
    rds.each do |row|
      # {:team_id=>1, :student_id=>2, :n_responses_total=>30, :avg_perc_complete=>0.1e3,
      # :response_avg_partial_total=>0.9222222222222222, :response_avg_total=>0.9222222222222222}
      sheet.add_row [teams[row[:team_id]],
                     students[row[:student_id]],
                     row[:n_responses_total],
                     row[:avg_perc_complete].to_i,
                     excel_percentage_from_proportion(row[:response_avg_partial_total]),
                     excel_percentage_from_proportion(row[:response_avg_total]),
                     excel_grade(@gs, row[:response_avg_partial_total]),
                     excel_grade(@gs, row[:response_avg_total])
                    ]
    end
  end

  headers["Content-Disposition"] = "attachment;filename=excel_result_#{@assessment.id}.xlsx"
  content_type 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    @package.to_stream


end


get '/assessment/:id/duplicate' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])

  @criteria_hash=@assessment.criteria_hash

  haml "assessments/prepare_duplicate".to_sym, escape_html: false
end

post '/assessment/:id/duplicate' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  original_assessment_id=params['origin_id']
  @assessment=Assessment[original_assessment_id]
  raise Coeval::NoAssessmentIdError, original_assessment_id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])

  @criteria_hash=@assessment.criteria_hash
  datetime_values=assessment_datetime_values(params)
  halt_invalid_assessment_datetime_order(datetime_values)
  # Primero, genero el archivo de copia
  new_assessment_id=nil
  $db.transaction(:rollback=>:reraise) do

    @new_assessment=Assessment.create(
      name:params["name"].strip,
      course_id:@assessment[:course_id],
      description:params["description"],
      active:!params["active"].nil?,
      grade_system: params['grade_system'].strip,
      grade_parameter_1: params['grade_parameter_1']=="" ? nil : params['grade_parameter_1'],
      grade_parameter_2: params['grade_parameter_2']=="" ? nil : params['grade_parameter_2'],
      start_time_evaluation:datetime_values[:start_time_evaluation],
      end_time_evaluation:datetime_values[:end_time_evaluation],
      start_time_feedback:datetime_values[:start_time_feedback],
      end_time_feedback:datetime_values[:end_time_feedback]
    )
    new_assessment_id=@new_assessment[:id]
    params['criterion'].each_pair do |index, order|
      if order.strip!=""
        AssessmentCriterion.create(assessment_id: new_assessment_id,
                                   criterion_id: index,
                                   criterion_order:order)
      end
    end

    @assessment.teams.each do |team|
      team_id=team[:id]
      if !params['team_active'].nil? and params['team_active'][team_id.to_s]
        new_team=Team.create(name: params['team_name'][team_id.to_s], assessment_id:new_assessment_id)

        $db.run("INSERT INTO student_teams (student_id, team_id) SELECT student_id, #{new_team[:id]} FROM
student_teams WHERE team_id=#{team_id}")
      end
    end
  end
  if new_assessment_id
    add_message(::I18n::t(:Correct_assessment_duplicate))

    redirect url("/assessment/#{new_assessment_id}")
  else
    add_message(::I18n::t(:Incorrect_assessment_duplicate))
    redirect url("/assessment/#{original_assessment_id}")
  end

end


post '/assessment/:id/edit' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  halt 403 if course_assistant_for_assessment?(@assessment, session['user_id'])

  datetime_values=assessment_datetime_values(params)
  halt_invalid_assessment_datetime_order(datetime_values)

  if params["name"].length>0
    #$log.info(params)
    @assessment.update(name:params["name"].strip,
                       description:params["description"],
                       active:!params["active"].nil?,
                       grade_system: params['grade_system'].strip,
                       grade_parameter_1: params['grade_parameter_1']=="" ? nil : params['grade_parameter_1'],
                       grade_parameter_2: params['grade_parameter_2']=="" ? nil : params['grade_parameter_2'],
                       start_time_evaluation:datetime_values[:start_time_evaluation],
                       end_time_evaluation:datetime_values[:end_time_evaluation],
                       start_time_feedback:datetime_values[:start_time_feedback],
                       end_time_feedback:datetime_values[:end_time_feedback]
                       )


  end

  params.fetch("criterion", {}).each_pair do |criterion_id, criterion_order|
    if criterion_order.strip.length>0
      ac=AssessmentCriterion.find_or_create(assessment_id:id, criterion_id:criterion_id)
      ac.update(criterion_order:criterion_order)
    else
      AssessmentCriterion.where(assessment_id:id, criterion_id:criterion_id).delete
    end

  end

  @criteria_hash=@assessment.criteria_hash

  haml "assessments/edit".to_sym, escape_html: false
end


get '/assessment/:id/check_open_ended_responses' do |id|
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  assistant_team_ids=assistant_visible_team_ids_for(@assessment, session['user_id'])
  course_assistant=course_assistant_for_assessment?(@assessment, session['user_id'])
  halt 403 unless (auth_to('assessment_admin') && !course_assistant) || (auth_to('assessment_view') && assistant_team_ids.any?)

  @open_ended=@assessment.open_ended_responses
  @open_ended=@open_ended.where(team_id:assistant_team_ids) if course_assistant || !auth_to('assessment_admin')
  @open_ended=@open_ended.order_by(:team_id, :criterion_id, :student_from, :student_to)
  #@gs=Coeval::GradingSystem.new(@assessment)
  haml "assessments/check_open_ended_responses".to_sym, escape_html: false
end

post '/assessment/:id/check_open_ended_responses' do |id|
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment
  assistant_team_ids=assistant_visible_team_ids_for(@assessment, session['user_id'])
  course_assistant=course_assistant_for_assessment?(@assessment, session['user_id'])
  halt 403 unless (auth_to('assessment_admin') && !course_assistant) || (auth_to('assessment_view') && assistant_team_ids.any?)
  allowed_response_ids=nil
  if course_assistant || !auth_to('assessment_admin')
    allowed_response_ids=@assessment.open_ended_responses.where(team_id:assistant_team_ids).map(:ass_id)
  end
  @result=Result.new
  params.fetch("response_total", {}).each_pair do |criterion, values_total|
    values_total=values_total.select {|response_id| allowed_response_ids.include?(response_id.to_i)} if allowed_response_ids
    values_to_omit=[]
    if params['response'] and params['response'][criterion]
      values_to_omit=params['response'][criterion].keys
    end
    values_to_omit=values_to_omit.select {|response_id| allowed_response_ids.include?(response_id.to_i)} if allowed_response_ids
    values_to_maintain=values_total-values_to_omit
      $db.transaction do
        if values_to_maintain.length>0
          AssessmentResponse.where(criterion_id: criterion,
                                   student_assessment_id:values_to_maintain).update(omitted:false)
          @result.success("Se presentan #{values_to_maintain.length} del criterio #{criterion}")

        end
        if values_to_omit.length>0
          AssessmentResponse.where(criterion_id: criterion, student_assessment_id:values_to_omit).update(omitted:true)
          @result.success("Se omiten #{values_to_omit.length} del criterio #{criterion}")
        end
      end
  end
  add_result(@result)
  @open_ended=@assessment.open_ended_responses
  @open_ended=@open_ended.where(team_id:assistant_team_ids) if course_assistant || !auth_to('assessment_admin')
  @open_ended=@open_ended.order_by(:team_id, :criterion_id, :student_from, :student_to)
  haml "assessments/check_open_ended_responses".to_sym, escape_html: false
end



get '/assessment/:id/from/:student_from/to/:student_to' do |id, student_from_id, student_to_id|
  halt 403 unless (auth_to('assessment_evaluate'))

  if not is_session_user(student_from_id)
    halt 403
  end

  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id if !@assessment
  @student_from=User[student_from_id]
  raise Coeval::NoUserIdError, student_from_id if !@student_from
  @student_to=User[student_to_id]
  raise Coeval::NoUserIdError, student_to_id if !@student_to

  @cem=Coeval::CoevaluationManager.new(@assessment, @student_from, @student_to)
  unless @cem.valid?
    add_message(@cem.result.message)
    redirect back
  end

  #$log.info(@cem.student_criteria)


  haml "assessments/evaluate_from_to".to_sym, escape_html: false
end

post '/assessment/receive_response' do
  $log.info(params)
  halt 403 unless (auth_to('assessment_evaluate'))
  @assessment=Assessment[params["assessment_id"]]
  raise Coeval::NoAssessmentIdError, params["assessment_id"] if !@assessment
  @student_from=User[params["student_from"]]
  raise Coeval::NoUserIdError, params["student_from"] if !@student_from
  @student_to=User[params["student_to"]]
  raise Coeval::NoUserIdError, params["student_to"] if !@student_to

  if not is_session_user(@student_from[:id])
    halt 403
  end

  @cem=Coeval::CoevaluationManager.new(@assessment, @student_from, @student_to)
  unless @cem.valid?
    add_result(@cem.resultmessage)
    redirect back
  end

  if @cem.student_assessment[:complete]
    add_message(t(:Assessment_already_complete), :warning)
    redirect back
  end

  @cem.update_assessment(params)

  if params['save_and_submit']
    complete_assessment=@cem.validate_complete_assessment

    if not complete_assessment
      add_result(@cem.result)
      redirect url("/assessment/#{@assessment[:id]}/from/#{@student_from[:id]}/to/#{@student_to[:id]}")
    end
  end
  add_result(@cem.result)
  redirect url("/assessment/#{@assessment[:id]}")

end



# @!endgroup

# Only the course lead with management permission or a system administrator.
def can_manage_assessment_schedule?(assessment)
  user = User[session['user_id']]
  user && (user[:role_id] == 'administrator' ||
    (auth_to('course_admin') && assessment.course[:teacher_id] == user[:id]))
end

post '/assessment/:id/schedule/:action' do |id, action|
  assessment = Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless assessment
  halt 403 unless can_manage_assessment_schedule?(assessment)
  halt 404 unless %w[open_evaluation open_feedback close_feedback].include?(action)

  now = Time.now
  week = 7 * 24 * 60 * 60
  values = case action
           when 'open_evaluation'
             changes = {start_time_evaluation: now - 60 * 60}
             [:start_time_feedback, :end_time_feedback].each do |field|
               changes[field] = assessment[field] + week unless assessment[field].nil?
             end
             changes
           when 'open_feedback'
             {end_time_evaluation: now, start_time_feedback: now, end_time_feedback: now + week}
           when 'close_feedback'
             {end_time_feedback: now}
           end
  assessment.update(values)
  add_message(t(:Assessment_schedule_updated))
  redirect url("/assessment/#{assessment[:id]}")
end
