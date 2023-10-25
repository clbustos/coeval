# Coeval
# https://github.com/clbustos/coeval
# Copyright (c) 2023, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information


# @!group Assessments


get '/assessments' do
  halt 403 unless (auth_to('assessment_view'))

  @assessments=Assessment.order(:course_id, :name)
  @courses_h=Course.order(:active, :name).to_hash(:id, :name)

  haml :assessments, escape_html: false
end




get '/assessment/:id' do |id|
  halt 403 unless (auth_to('assessment_view') or auth_to('assessment_evaluate'))
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  @gs=Coeval::GradingSystem.new(@assessment)
  haml "assessments/view".to_sym, escape_html: false
end

get '/assessment/:id/edit' do |id|
  halt 403 unless auth_to('assessment_view')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  haml "assessments/edit".to_sym, escape_html: false
end

get '/assessment/:id/export_excel' do |id|
  require 'caxlsx'

  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  @gs=Coeval::GradingSystem.new(@assessment)
  rds=@assessment.response_detail_student.all
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
                     (row[:response_avg_partial_total]*100.0).to_i,
                     (row[:response_avg_total]*100.0).to_i,
                     @gs.grade(row[:response_avg_partial_total]),
                     @gs.grade(row[:response_avg_total])
                    ]
    end
  end

  headers["Content-Disposition"] = "attachment;filename=excel_result_#{@assessment.id}.xlsx"
  content_type 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    @package.to_stream


end


post '/assessment/:id/edit' do |id|
  halt 403 unless auth_to('assessment_view')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  raise Coeval::NoAssessmentIdError, id unless @assessment

  if params["name"].length>0
    $log.info(params)
    @assessment.update(name:params["name"].strip,
                       description:params["description"],
                       active:!params["active"].nil?,
                       start_time_evaluation:!params['start_time_evaluation_nil'].nil? ? nil: params['start_time_evaluation'],
                       end_time_evaluation:!params['end_time_evaluation_nil'].nil? ? nil :  params['end_time_evaluation'],
                      start_time_feedback:!params['start_time_feedback_nil'].nil? ? nil : params['start_time_feedback'],
                        end_time_feedback:!params['end_time_feedback_nil'].nil? ? nil : params['end_time_feedback']
                       )

  end



  haml "assessments/edit".to_sym, escape_html: false
end


get '/assessment/:id/check_open_ended_responses' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]

  @open_ended=@assessment.open_ended_responses.order_by(:team_id, :criterion_id, :student_from, :student_to )
  #@gs=Coeval::GradingSystem.new(@assessment)
  haml "assessments/check_open_ended_responses".to_sym, escape_html: false
end

post '/assessment/:id/check_open_ended_responses' do |id|
  halt 403 unless auth_to('assessment_admin')
  @user=User[session["user_id"]]
  @assessment=Assessment[id]
  @result=Result.new
  params["response_total"].each_pair do |criterion, values_total|
    values_to_omit=[]
    if params['response'] and params['response'][criterion]
      values_to_omit=params['response'][criterion].keys
    end
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
  @open_ended=@assessment.open_ended_responses.order_by(:team_id, :criterion_id, :student_from, :student_to )
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
