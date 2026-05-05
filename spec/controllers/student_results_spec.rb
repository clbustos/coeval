# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Student result presentation' do
  describe 'GET /team/:id/student/:student_id' do
    it 'shows the selected student quantitative feedback' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      get "/team/#{scenario[:team][:id]}/student/#{scenario[:student][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Student One')
      expect(last_response.body).to include('Collaboration')
      expect(last_response.body).to include('7.0 (100%)')
    end

    it 'requires assessment_view authorization' do
      scenario = create_course_scenario
      login_as(scenario[:student])

      get "/team/#{scenario[:team][:id]}/student/#{scenario[:student][:id]}"

      expect(last_response.status).to eq(403)
    end
  end

  describe 'team distribution' do
    it 'creates teams and moves course students into the selected team' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      post "/assessment/#{scenario[:assessment][:id]}/teams", name: 'Team B'
      team_b = Team[name: 'Team B', assessment_id: scenario[:assessment][:id]]

      post "/assessment/#{scenario[:assessment][:id]}/student_teams",
           student_ids: [scenario[:student][:id], scenario[:peer][:id]],
           team_id: team_b[:id]

      expect(last_response).to be_redirect
      expect(StudentTeam[team_id: team_b[:id], student_id: scenario[:student][:id]]).not_to be_nil
      expect(StudentTeam[team_id: team_b[:id], student_id: scenario[:peer][:id]]).not_to be_nil
      expect(StudentTeam[team_id: scenario[:team][:id], student_id: scenario[:student][:id]]).to be_nil
    end
  end
end
