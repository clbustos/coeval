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

    it 'lists teams by assessment with their teacher and members' do
      scenario = create_course_scenario
      team = Team.create(
        name: 'Team Alpha',
        assessment_id: scenario[:assessment][:id],
        teacher_id: scenario[:teacher][:id]
      )
      StudentTeam.create(team_id: team[:id], student_id: scenario[:student][:id])
      StudentTeam.create(team_id: team[:id], student_id: scenario[:peer][:id])
      login_as(scenario[:teacher])

      get "/course/#{scenario[:course][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Assessment A')
      expect(last_response.body).to include('Team Alpha')
      expect(last_response.body).to include('Teacher')
      expect(last_response.body).to include('Student One')
      expect(last_response.body).to include('Peer Student')
    end
  end

  describe 'assistant teacher course access' do
    it 'shows only the teams assigned to the assistant' do
      scenario = create_course_scenario
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      assistant_team=Team.create(
        name:'Assistant Team',
        assessment_id:scenario[:assessment][:id],
        teacher_id:scenario[:assistant][:id]
      )
      StudentTeam.create(team_id:assistant_team[:id], student_id:scenario[:student][:id])
      login_as(scenario[:assistant])

      get "/course/#{scenario[:course][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Assessment A')
      expect(last_response.body).to include('Assistant Team')
      expect(last_response.body).not_to include('Team A')
    end

    it 'denies access to courses not assigned to the assistant' do
      scenario = create_course_scenario
      login_as(scenario[:assistant])

      get "/course/#{scenario[:course][:id]}"

      expect(last_response.status).to eq(403)
    end

    it 'lets an assistant with monitor permission see every team in the assigned course' do
      scenario = create_course_scenario
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      Team.create(
        name:'Assistant Team',
        assessment_id:scenario[:assessment][:id],
        teacher_id:scenario[:assistant][:id]
      )
      Role['guest'].add_auth_to(Authorization['course_assistant_monitor'])
      login_as(scenario[:assistant])

      get "/course/#{scenario[:course][:id]}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Team A')
      expect(last_response.body).to include('Assistant Team')
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

  describe 'GET /course/:id/assessment/new' do
    it 'moves the new assessment form to its own page' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      get "/course/#{scenario[:course][:id]}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/course/#{scenario[:course][:id]}/assessment/new")
      expect(last_response.body).not_to include("action='/course/#{scenario[:course][:id]}/assessments'")

      get "/course/#{scenario[:course][:id]}/assessment/new"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("action='/course/#{scenario[:course][:id]}/assessments'")
      expect(last_response.body).to include("name='name'")
    end

    it 'denies access to assistant teachers' do
      scenario = create_course_scenario
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      login_as(scenario[:assistant])

      get "/course/#{scenario[:course][:id]}/assessment/new"

      expect(last_response.status).to eq(403)
    end
  end

  describe 'GET /course/:id/excel' do
    it 'moves Excel import and export to a dedicated page' do
      scenario = create_course_scenario
      login_as(scenario[:teacher])

      get "/course/#{scenario[:course][:id]}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/course/#{scenario[:course][:id]}/excel")
      expect(last_response.body).not_to include("action='/course/excel_import'")

      get "/course/#{scenario[:course][:id]}/excel"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Excel Import / Export')
      expect(last_response.body).to include("/course/#{scenario[:course][:id]}/users_batch_edition/excel_export")
      expect(last_response.body).to include("action='/course/excel_import'")
    end

    it 'denies the Excel page to assistant teachers' do
      scenario = create_course_scenario
      AssistantTeacher.create(course_id:scenario[:course][:id], teacher_id:scenario[:assistant][:id])
      login_as(scenario[:assistant])

      get "/course/#{scenario[:course][:id]}/excel"

      expect(last_response.status).to eq(403)
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

  describe 'GET /course/:id/users_batch_edition/excel_export' do
    it 'exports a complete import template when the course has no students' do
      require 'simple_xlsx_reader'
      SimpleXlsxReader.configuration.auto_slurp = true
      scenario = create_course_scenario
      StudentCourse.where(course_id: scenario[:course][:id]).delete
      login_as(scenario[:teacher])

      get "/course/#{scenario[:course][:id]}/users_batch_edition/excel_export"

      expect(last_response.status).to eq(200)
      tempfile = Tempfile.new(['empty-course-template', '.xlsx'])
      begin
        tempfile.binmode
        tempfile.write(last_response.body)
        tempfile.close
        sheet = SimpleXlsxReader.open(tempfile.path).sheets.first
        expect(sheet.headers).to eq(%w[login email language name password assessment team assistant_teacher])
        expect(sheet.data).to be_empty
      ensure
        tempfile.unlink
      end
    end
  end
end
