# encoding: UTF-8

ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = 'sqlite::memory:'

require 'fileutils'
FileUtils.mkdir_p(File.expand_path('../log', __dir__))

require 'rack/test'
require 'rspec'
require 'sequel'

require_relative '../model/init'
require_relative '../lib/coeval/create_schema'

Coeval::CreateSchema.new($db).migrate!

require_relative '../app'

Sinatra::Application.set :environment, :test
Sinatra::Application.set :raise_errors, true
Sinatra::Application.set :show_exceptions, false

module SpecDatabase
  def reset_test_database!
    drop_test_database_objects!
    Coeval::CreateSchema.new($db).migrate!
    Coeval::CreateSchema.new($db).seed_base_data!
  end

  def drop_test_database_objects!
    $db.run('DROP VIEW IF EXISTS assessments_results_raw')
    $db.run('PRAGMA foreign_keys = OFF')
    $db.tables.reverse_each { |table| $db.drop_table?(table) }
  ensure
    $db.run('PRAGMA foreign_keys = ON') if $db
  end
end

module SpecData
  PASSWORD = 'secret'.freeze

  def app
    Sinatra::Application
  end

  def create_user(login:, role_id:, name: login, institution_id: default_institution_id)
    User.create(
      login: login,
      name: name,
      email: "#{login}@example.test",
      password: Digest::SHA1.hexdigest(PASSWORD),
      language: 'en',
      role_id: role_id,
      institution_id: institution_id,
      active: true
    )
  end

  def login_as(user)
    post '/login', user: user[:login], password: PASSWORD
    follow_redirect! if last_response.redirect?
  end

  def default_institution_id
    Institution[name: 'Universidad de Concepción'][:id]
  end

  def create_course_scenario
    teacher = create_user(login: 'teacher', role_id: 'teacher', name: 'Teacher')
    assistant = create_user(login: 'assistant', role_id: 'guest', name: 'Assistant')
    student = create_user(login: 'student', role_id: 'student', name: 'Student One')
    peer = create_user(login: 'peer', role_id: 'student', name: 'Peer Student')

    course = Course.create(
      name: 'Course A',
      description: 'Course scenario',
      institution_id: default_institution_id,
      teacher_id: teacher[:id],
      active: true
    )
    StudentCourse.create(course_id: course[:id], student_id: student[:id])
    StudentCourse.create(course_id: course[:id], student_id: peer[:id])

    now = Time.now
    assessment = Assessment.create(
      course_id: course[:id],
      active: true,
      name: 'Assessment A',
      description: 'Assessment scenario',
      start_time_evaluation: now - (60 * 60),
      end_time_evaluation: now + (60 * 60),
      start_time_feedback: now - (60 * 60),
      end_time_feedback: now + (60 * 60),
      grade_system: 'chilean',
      grade_parameter_1: 60
    )

    Criterion.create(id: 'criterion_1', name: 'Collaboration', criterion_type: 'numeric')
    CriterionLevel.create(criterion_id: 'criterion_1', points: 1, description: 'Low')
    CriterionLevel.create(criterion_id: 'criterion_1', points: 5, description: 'High')
    AssessmentCriterion.create(assessment_id: assessment[:id], criterion_id: 'criterion_1', criterion_order: 1)

    team = Team.create(name: 'Team A', assessment_id: assessment[:id], teacher_id: teacher[:id])
    StudentTeam.create(team_id: team[:id], student_id: student[:id])
    StudentTeam.create(team_id: team[:id], student_id: peer[:id])

    [student, peer].product([student, peer]).each do |student_from, student_to|
      student_assessment = StudentAssessment.create(
        team_id: team[:id],
        student_from: student_from[:id],
        student_to: student_to[:id],
        complete: true,
        saved: true,
        sent: Time.now
      )
      AssessmentResponse.create(
        student_assessment_id: student_assessment[:id],
        criterion_id: 'criterion_1',
        response_value: '5',
        omitted: false
      )
    end

    {
      teacher: teacher,
      assistant: assistant,
      student: student,
      peer: peer,
      course: course,
      assessment: assessment,
      team: team
    }
  end
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include SpecDatabase
  config.include SpecData

  config.before do
    reset_test_database!
    clear_cookies
  end
end
