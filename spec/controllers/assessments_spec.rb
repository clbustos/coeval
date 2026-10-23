# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Assessments controller' do
  it 'saves course wall clocks as instants and shows the course zone' do
    scenario = create_course_scenario
    scenario[:course].update(timezone:'Asia/Tokyo')
    login_as(scenario[:teacher])
    assessment = scenario[:assessment]
    post "/assessment/#{assessment[:id]}/edit", assessment_edit_params
    expect(last_response.status).to eq(200)
    expect(assessment.refresh[:start_time_evaluation].utc).to eq(Time.utc(2026, 5, 4, 0))
    get "/assessment/#{assessment[:id]}/edit"
    expect(last_response.body).to include('2026-05-04T09:00', 'Asia/Tokyo')
    get '/logout'
    login_as(scenario[:student])
    get '/'
    expect(last_response.body).to include('Asia/Tokyo')
  end

  def assessment_edit_params(overrides={})
    {
      name: 'Assessment A edited',
      description: 'Assessment edited from spec',
      active: 'on',
      grade_system: 'chilean',
      grade_parameter_1: '60',
      grade_parameter_2: '',
      start_time_evaluation: '2026-05-04T09:00',
      end_time_evaluation: '2026-05-04T10:00',
      start_time_feedback: '2026-05-04T10:00',
      end_time_feedback: '2026-05-04T11:00',
      criterion: { 'criterion_1' => '1' }
    }.merge(overrides)
  end

  describe 'GET /assessment/:id' do
    it 'shows the assigned teacher for every team' do
      scenario = create_course_scenario
      Team.create(
        name: 'Team with teacher',
        assessment_id: scenario[:assessment][:id],
        teacher_id: scenario[:assistant][:id]
      )
      login_as(scenario[:teacher])

      get "/assessment/#{scenario[:assessment][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Team with teacher')
      expect(last_response.body).to include('Assistant')
    end

    it 'links to the student survey preview' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      get "/assessment/#{scenario[:assessment][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/assessment/#{scenario[:assessment][:id]}/preview")
      expect(last_response.body).to include('Preview survey')
    end
  end

  describe 'GET /assessment/:id/preview' do
    it 'shows the survey structure without an enabled form' do
      scenario = create_course_scenario
      Criterion['criterion_1'].update(criterion_type:'ordered_levels')
      Criterion.create(id:'open_comment', name:'Comment', criterion_type:'open_ended')
      AssessmentCriterion.create(
        assessment_id:scenario[:assessment][:id],
        criterion_id:'open_comment',
        criterion_order:2
      )
      login_as(scenario[:teacher])

      get "/assessment/#{scenario[:assessment][:id]}/preview"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Student survey preview')
      expect(last_response.body).to include('Collaboration')
      expect(last_response.body).to include('Comment')
      expect(last_response.body).to include('Low')
      expect(last_response.body).to include('High')
      expect(last_response.body).to include('disabled')
      expect(last_response.body).not_to include('<form')
      expect(last_response.body).not_to include('/assessment/receive_response')
    end

    it 'denies students without assessment view permission' do
      scenario = create_course_scenario
      login_as(scenario[:student])

      get "/assessment/#{scenario[:assessment][:id]}/preview"

      expect(last_response.status).to eq(403)
    end
  end

  describe 'teacher assignation' do
    it 'shows teams with their assigned teacher and the available teachers' do
      scenario = create_course_scenario
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      login_as(scenario[:teacher])

      get "/assessment/#{scenario[:assessment][:id]}/teacher_assignation"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Team A')
      expect(last_response.body).to include('Teacher')
      expect(last_response.body).to include('Assistant')
      expect(last_response.body).to include("name='team_ids[]'")
      expect(last_response.body).to include("<select class='form-control' id='teacher_id' name='teacher_id' required>")
    end

    it 'assigns the selected teams to a teacher' do
      scenario = create_course_scenario
      second_team=Team.create(name:'Team B', assessment_id:scenario[:assessment][:id], teacher_id:scenario[:teacher][:id])
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      login_as(scenario[:teacher])

      post "/assessment/#{scenario[:assessment][:id]}/teacher_assignation",
           team_ids:[scenario[:team][:id], second_team[:id]],
           teacher_id:scenario[:assistant][:id]

      expect(last_response).to be_redirect
      expect(Team[scenario[:team][:id]][:teacher_id]).to eq(scenario[:assistant][:id])
      expect(Team[second_team[:id]][:teacher_id]).to eq(scenario[:assistant][:id])
    end

    it 'shows an error when no teams are selected' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      post "/assessment/#{scenario[:assessment][:id]}/teacher_assignation",
           teacher_id:scenario[:teacher][:id]
      follow_redirect!

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('No teams selected')
      expect(Team[scenario[:team][:id]][:teacher_id]).to eq(scenario[:teacher][:id])
    end
  end

  describe 'POST /assessment/:id/edit' do
    [:end_time_evaluation, :end_time_feedback].each do |end_field|
      it "rejects #{end_field} equal to its start" do
        scenario = create_course_scenario
        login_as(scenario[:teacher])
        original = scenario[:assessment].values.dup
        start_field = end_field.to_s.sub('end_', 'start_').to_sym
        post "/assessment/#{scenario[:assessment][:id]}/edit",
             assessment_edit_params(end_field => assessment_edit_params[start_field]),
             'HTTP_REFERER' => "/assessment/#{scenario[:assessment][:id]}/edit"
        expect(last_response).to be_redirect
        expect(scenario[:assessment].refresh.values).to eq(original)
      end
    end

    it 'updates ordered dates and allows dates without a fixed value' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      post "/assessment/#{scenario[:assessment][:id]}/edit",
           assessment_edit_params(
             start_time_feedback_nil: 'on',
             start_time_feedback: ''
           )

      assessment = Assessment[scenario[:assessment][:id]]
      expect(last_response.status).to eq(200)
      expect(assessment[:name]).to eq('Assessment A edited')
      expect(assessment[:start_time_evaluation].strftime('%Y-%m-%dT%H:%M')).to eq('2026-05-04T09:00')
      expect(assessment[:end_time_evaluation].strftime('%Y-%m-%dT%H:%M')).to eq('2026-05-04T10:00')
      expect(assessment[:start_time_feedback]).to be_nil
      expect(assessment[:end_time_feedback].strftime('%Y-%m-%dT%H:%M')).to eq('2026-05-04T11:00')
    end

    it 'rejects fixed dates that break the assessment order' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      post "/assessment/#{scenario[:assessment][:id]}/edit",
           assessment_edit_params(
             end_time_evaluation: '2026-05-04T08:30'
           ),
           'HTTP_REFERER' => "/assessment/#{scenario[:assessment][:id]}/edit"

      assessment = Assessment[scenario[:assessment][:id]]
      expect(last_response).to be_redirect
      expect(last_response.location).to include("/assessment/#{scenario[:assessment][:id]}/edit")
      expect(assessment[:name]).to eq('Assessment A')
    end

    it 'ignores blank criteria that are not assigned to the assessment' do
      scenario = create_course_scenario
      Criterion.create(id: 'criterion_blank', name: 'Blank criterion', criterion_type: 'numeric')
      login_as(scenario[:teacher])

      post "/assessment/#{scenario[:assessment][:id]}/edit",
           assessment_edit_params(
             criterion: {
               'criterion_1' => '1',
               'criterion_blank' => ''
             }
           )

      expect(last_response.status).to eq(200)
      expect(AssessmentCriterion[assessment_id: scenario[:assessment][:id], criterion_id: 'criterion_blank']).to be_nil
    end
  end

  describe 'assessment duplication dates' do
    it 'uses current dates in the form and saves them without changing the original' do
      scenario = create_course_scenario
      original = scenario[:assessment].values.dup
      login_as(scenario[:teacher])
      now = Time.local(2026, 10, 23, 12, 0, 0)
      allow(Time).to receive(:now).and_return(now)

      get "/assessment/#{scenario[:assessment][:id]}/duplicate"

      expect(last_response.status).to eq(200)
      require 'nokogiri'
      form = Nokogiri::HTML(last_response.body)
      dates = {}
      expected = [now, now + 30 * 86400, now + 30 * 86400, now + 60 * 86400]
      ASSESSMENT_DATETIME_FIELDS.zip(expected).each do |field, time|
        value = form.at_css("input[name='#{field}']")['value']
        local = Coeval::TimeZone.local(time, scenario[:course].timezone)
        expect(value).to eq(local.strftime('%Y-%m-%dT%H:%M'))
        expect(form.at_css("input[name='#{field}_nil']")['checked']).to be_nil
        dates[field] = value
      end

      post "/assessment/#{scenario[:assessment][:id]}/duplicate",
           assessment_edit_params(dates.merge(origin_id: scenario[:assessment][:id].to_s))

      expect(last_response).to be_redirect
      duplicate = Assessment.order(:id).last
      expect(duplicate[:id]).not_to eq(scenario[:assessment][:id])
      ASSESSMENT_DATETIME_FIELDS.zip(expected).each do |field, time|
        expect(duplicate[field]).to eq(time)
      end
      expect(scenario[:assessment].refresh.values).to eq(original)
    end
  end

  describe 'GET /assessment/:id/export_excel' do
    it 'exports when partial averages are nil' do
      scenario = create_course_scenario
      AssessmentResponse.dataset.update(response_value: nil)
      login_as(scenario[:teacher])

      get "/assessment/#{scenario[:assessment][:id]}/export_excel"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end
  end

  describe 'assistant teacher assessment access' do
    before do
      @scenario=create_course_scenario
      AssistantTeacher.create(course_id:@scenario[:course][:id], teacher_id:@scenario[:assistant][:id])
      @assistant_team=Team.create(
        name:'Assistant Team',
        assessment_id:@scenario[:assessment][:id],
        teacher_id:@scenario[:assistant][:id]
      )
      StudentTeam.create(team_id:@assistant_team[:id], student_id:@scenario[:student][:id])
      login_as(@scenario[:assistant])
    end

    it 'shows only assigned groups and the two permitted actions' do
      get "/assessment/#{@scenario[:assessment][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Assistant Team')
      expect(last_response.body).not_to include('Team A')
      expect(last_response.body).to include("/assessment/#{@scenario[:assessment][:id]}/check_open_ended_responses")
      expect(last_response.body).to include("/assessment/#{@scenario[:assessment][:id]}/export_excel")
      expect(last_response.body).not_to include("/assessment/#{@scenario[:assessment][:id]}/edit")
      expect(last_response.body).not_to include("/assessment/#{@scenario[:assessment][:id]}/teacher_assignation")
    end

    it 'allows open-response review and Excel export' do
      get "/assessment/#{@scenario[:assessment][:id]}/check_open_ended_responses"
      expect(last_response.status).to eq(200)

      get "/assessment/#{@scenario[:assessment][:id]}/export_excel"
      expect(last_response.status).to eq(200)
    end

    it 'shows open responses only from teams assigned to the assistant' do
      Criterion.create(id:'open_comment', name:'Comment', criterion_type:'open_ended')
      AssessmentCriterion.create(
        assessment_id:@scenario[:assessment][:id],
        criterion_id:'open_comment',
        criterion_order:2
      )
      lead_student_assessment=StudentAssessment[
        team_id:@scenario[:team][:id],
        student_from:@scenario[:student][:id],
        student_to:@scenario[:student][:id]
      ]
      assistant_student_assessment=StudentAssessment.create(
        team_id:@assistant_team[:id],
        student_from:@scenario[:student][:id],
        student_to:@scenario[:student][:id],
        complete:true,
        saved:true
      )
      AssessmentResponse.create(
        student_assessment_id:lead_student_assessment[:id],
        criterion_id:'open_comment',
        response_value:'Lead team private response',
        omitted:false
      )
      AssessmentResponse.create(
        student_assessment_id:assistant_student_assessment[:id],
        criterion_id:'open_comment',
        response_value:'Assistant team response',
        omitted:false
      )

      get "/assessment/#{@scenario[:assessment][:id]}/check_open_ended_responses"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Assistant team response')
      expect(last_response.body).not_to include('Lead team private response')
    end

    it 'denies administrative and team-detail actions' do
      get "/assessment/#{@scenario[:assessment][:id]}/edit"
      expect(last_response.status).to eq(403)

      get "/assessment/#{@scenario[:assessment][:id]}/teacher_assignation"
      expect(last_response.status).to eq(403)

      get "/team/#{@assistant_team[:id]}"
      expect(last_response.status).to eq(403)
    end
  end

  describe 'assistant with an administrative teacher role' do
    it 'cannot edit, assign teachers, duplicate, or delete the assessment' do
      scenario=create_course_scenario
      administrative_assistant=create_user(
        login:'administrative_assistant',
        role_id:'teacher',
        name:'Administrative Assistant'
      )
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:administrative_assistant[:id])
      Team.create(
        name:'Administrative Assistant Team',
        assessment_id:scenario[:assessment][:id],
        teacher_id:administrative_assistant[:id]
      )
      login_as(administrative_assistant)

      get "/assessment/#{scenario[:assessment][:id]}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include("/assessment/#{scenario[:assessment][:id]}/edit")
      expect(last_response.body).not_to include("/assessment/#{scenario[:assessment][:id]}/teacher_assignation")
      expect(last_response.body).not_to include("/assessment/#{scenario[:assessment][:id]}/duplicate")
      expect(last_response.body).not_to include("/assessment/#{scenario[:assessment][:id]}/delete")
      expect(last_response.body).not_to include("action='/assessment/#{scenario[:assessment][:id]}/student_teams'")

      get "/assessment/#{scenario[:assessment][:id]}/edit"
      expect(last_response.status).to eq(403)
      get "/assessment/#{scenario[:assessment][:id]}/teacher_assignation"
      expect(last_response.status).to eq(403)
      get "/assessment/#{scenario[:assessment][:id]}/duplicate"
      expect(last_response.status).to eq(403)
      get "/assessment/#{scenario[:assessment][:id]}/delete"
      expect(last_response.status).to eq(403)

      post "/assessment/#{scenario[:assessment][:id]}/student_teams",
           team_id:scenario[:team][:id], student_ids:[scenario[:student][:id]]
      expect(last_response.status).to eq(403)
    end
  end

  describe 'assistant course monitor permission' do
    it 'shows every team but keeps administrative actions disabled' do
      scenario=create_course_scenario
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      Team.create(
        name:'Assistant Team',
        assessment_id:scenario[:assessment][:id],
        teacher_id:scenario[:assistant][:id]
      )
      Role['guest'].add_auth_to(Authorization['course_assistant_monitor'])
      login_as(scenario[:assistant])

      get "/assessment/#{scenario[:assessment][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Team A')
      expect(last_response.body).to include('Assistant Team')
      expect(last_response.body).not_to include("/assessment/#{scenario[:assessment][:id]}/edit")
      expect(last_response.body).not_to include("/assessment/#{scenario[:assessment][:id]}/teacher_assignation")
    end
  end
end
