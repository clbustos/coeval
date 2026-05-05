# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Courses controller' do
  describe 'GET /courses' do
    it 'requires course_view authorization' do
      user = create_user(login: 'student1', role_id: 'student')
      login_as(user)

      get '/courses'

      expect(last_response.status).to eq(403)
    end
  end

  describe 'POST /course/new/edit' do
    it 'creates a course with the selected lead and assistant teachers' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      post '/course/new/edit',
           name: 'New Course',
           description: 'Created from spec',
           institution: default_institution_id.to_s,
           teacher: scenario[:teacher][:id].to_s,
           active: 'on',
           assistant_teacher: { scenario[:assistant][:id].to_s => 'on' }

      created_course = Course[name: 'New Course']
      expect(last_response).to be_redirect
      expect(last_response.location).to include("/course/#{created_course[:id]}")
      expect(created_course[:description]).to eq('Created from spec')
      expect(created_course[:active]).to eq(true)
      expect(created_course.assistant_teachers.map(:id)).to contain_exactly(scenario[:assistant][:id])
    end
  end

  describe 'student assignment' do
    it 'searches students by name from the course page' do
      scenario = create_course_scenario
      available_student = create_user(login: 'available_student', role_id: 'student', name: 'Available Student')
      login_as(scenario[:teacher])

      get "/course/#{scenario[:course][:id]}", student_search: 'Available'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include(available_student[:name])
    end

    it 'adds a selected student to student_courses' do
      scenario = create_course_scenario
      available_student = create_user(login: 'student_to_add', role_id: 'student', name: 'Student To Add')
      login_as(scenario[:teacher])

      post "/course/#{scenario[:course][:id]}/student_courses", user_id: available_student[:id]

      expect(last_response).to be_redirect
      expect(StudentCourse[course_id: scenario[:course][:id], student_id: available_student[:id]]).not_to be_nil
    end
  end

  describe 'POST /course/:id/assessments' do
    it 'creates an assessment for the course' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      post "/course/#{scenario[:course][:id]}/assessments",
           name: 'New Assessment',
           description: 'Created from course',
           grade_system: 'chilean',
           grade_parameter_1: '60',
           active: 'on'

      assessment = Assessment[name: 'New Assessment']
      expect(last_response).to be_redirect
      expect(last_response.location).to include("/assessment/#{assessment[:id]}")
      expect(assessment[:course_id]).to eq(scenario[:course][:id])
    end
  end

  describe 'GET /course/:id/assessments' do
    it 'lists assessments for the course' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      get "/course/#{scenario[:course][:id]}/assessments"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Assessment A')
      expect(last_response.body).to include('Course A')
    end
  end

  describe 'GET /course/:id/response_detail' do
    it 'requires course_admin authorization' do
      scenario = create_course_scenario
      login_as(scenario[:assistant])

      get "/course/#{scenario[:course][:id]}/response_detail"

      expect(last_response.status).to eq(403)
    end
  end
end
