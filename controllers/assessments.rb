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
  haml "assessments/view".to_sym, escape_html: false
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
