# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Dashboard' do
  describe 'GET /' do
    it 'shows active courses assigned to the lead teacher' do
      scenario = create_course_scenario
      inactive_course = Course.create(
        name: 'Inactive Course',
        description: 'Should not appear',
        institution_id: default_institution_id,
        teacher_id: scenario[:teacher][:id],
        active: false
      )
      inactive_assessment = Assessment.create(
        course_id: scenario[:course][:id],
        active: false,
        name: 'Inactive Assessment',
        description: 'Should not appear',
        start_time_evaluation: Time.now,
        end_time_evaluation: Time.now,
        start_time_feedback: Time.now,
        end_time_feedback: Time.now,
        grade_system: 'chilean',
        grade_parameter_1: 60
      )
      login_as(scenario[:teacher])

      get '/'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Active assigned courses')
      expect(last_response.body).to include(scenario[:course][:name])
      expect(last_response.body).to include(scenario[:assessment][:name])
      expect(last_response.body).to include("/assessment/#{scenario[:assessment][:id]}")
      expect(last_response.body).to include('Lead teacher')
      expect(last_response.body).not_to include(inactive_course[:name])
      expect(last_response.body).not_to include(inactive_assessment[:name])
    end

    it 'shows active courses assigned to an assistant teacher' do
      scenario = create_course_scenario
      AssistantTeacher.create(course_id: scenario[:course][:id], teacher_id: scenario[:assistant][:id])
      inactive_course = Course.create(
        name: 'Inactive assistant course',
        institution_id: default_institution_id,
        teacher_id: scenario[:teacher][:id],
        active: false
      )
      AssistantTeacher.create(course_id: inactive_course[:id], teacher_id: scenario[:assistant][:id])
      login_as(scenario[:assistant])

      get '/'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Active assigned courses')
      expect(last_response.body).to include(scenario[:course][:name])
      expect(last_response.body).to include(scenario[:assessment][:name])
      expect(last_response.body).to include("/assessment/#{scenario[:assessment][:id]}")
      expect(last_response.body).to include('Assistant teacher')
      expect(last_response.body).not_to include(inactive_course[:name])
    end
  end
end
