# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Assessments controller' do
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

  describe 'POST /assessment/:id/edit' do
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
end
