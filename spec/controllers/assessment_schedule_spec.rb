require_relative '../spec_helper'

RSpec.describe 'Assessment schedule actions' do
  before do
    @scenario = create_course_scenario
    @assessment = @scenario[:assessment]
    @now = Time.local(2026, 10, 23, 12, 0, 0)
    allow(Time).to receive(:now) { @now }
  end

  def schedule(action)
    post "/assessment/#{@assessment[:id]}/schedule/#{action}"
    @assessment.refresh
  end

  it 'opens entry and shifts existing feedback dates by one week' do
    login_as(@scenario[:teacher])
    start_feedback = @assessment[:start_time_feedback]
    schedule('open_evaluation')
    expect(last_response).to be_redirect
    expect(@assessment[:start_time_evaluation]).to eq(@now - 3600)
    expect(@assessment[:end_time_evaluation]).to eq(@now + 604800)
    expect(@assessment[:start_time_feedback]).to eq([start_feedback + 604800, @now + 604800].max)
    expect(@assessment[:end_time_feedback]).to be > @assessment[:start_time_feedback]
    expect(@assessment.moment_to_evaluate?).to be(true)
  end

  it 'repairs expired and reversed feedback dates when reopening evaluation' do
    login_as(@scenario[:teacher])
    @assessment.update(end_time_evaluation:@now - 86400,
                       start_time_feedback:@now - 604800 * 3,
                       end_time_feedback:@now - 604800 * 4)
    schedule('open_evaluation')
    expect(@assessment[:end_time_evaluation]).to eq(@now + 604800)
    expect(@assessment[:start_time_feedback]).to eq(@assessment[:end_time_evaluation])
    expect(@assessment[:end_time_feedback]).to eq(@assessment[:start_time_feedback] + 604800)
  end

  it 'rejects closing feedback before it starts' do
    login_as(@scenario[:teacher])
    @assessment.update(start_time_feedback:@now + 86400, end_time_feedback:@now + 172800)
    original = @assessment.values.dup
    post "/assessment/#{@assessment[:id]}/schedule/close_feedback", {},
         'HTTP_REFERER' => "/assessment/#{@assessment[:id]}"
    expect(last_response).to be_redirect
    expect(@assessment.refresh.values).to eq(original)
  end

  it 'preserves unset feedback dates when opening entry' do
    login_as(@scenario[:teacher])
    @assessment.update(start_time_feedback:nil, end_time_feedback:nil)
    schedule('open_evaluation')
    expect(@assessment[:start_time_feedback]).to be_nil
    expect(@assessment[:end_time_feedback]).to be_nil
  end

  it 'starts feedback now and closes it one week later' do
    login_as(@scenario[:teacher])
    schedule('open_feedback')
    expect(@assessment[:end_time_evaluation]).to eq(@now)
    expect(@assessment[:start_time_feedback]).to eq(@now)
    expect(@assessment[:end_time_feedback]).to eq(@now + 604800)
  end

  it 'closes feedback without changing the other dates' do
    login_as(@scenario[:teacher])
    @assessment.update(start_time_evaluation:@now - 10800, end_time_evaluation:@now - 7200,
                       start_time_feedback:@now - 3600)
    original = @assessment.values.dup
    schedule('close_feedback')
    expect(@assessment.values).to eq(original.merge(end_time_feedback:@now))
  end

  it 'changes only the selected assessment for each action' do
    login_as(@scenario[:teacher])
    other = Assessment.create(@assessment.values.reject { |key, _| key == :id }.merge(name:'Assessment B'))
    original = other.values.dup
    course_original = @scenario[:course].values.dup

    %w[open_evaluation open_feedback close_feedback].each do |action|
      @now += 60
      schedule(action)
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with("/assessment/#{@assessment[:id]}")
      expect(other.refresh.values).to eq(original)
      expect(@scenario[:course].refresh.values).to eq(course_original)
    end
  end

  it 'keeps schedule actions in the assessment detail rather than course views' do
    login_as(@scenario[:teacher])
    ["/course/#{@scenario[:course][:id]}", "/course/#{@scenario[:course][:id]}/assessments", '/assessments'].each do |path|
      get path
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include('/schedule/')
    end
  end

  it 'allows the system administrator' do
    admin = create_user(login:'admin', role_id:'administrator')
    login_as(admin)
    schedule('open_feedback')
    expect(last_response).to be_redirect
  end

  it 'rejects students, assistants and teachers of other courses' do
    AssistantTeacher.create(course_id:@scenario[:course][:id], teacher_id:@scenario[:assistant][:id])
    other_teacher = create_user(login:'other_teacher', role_id:'teacher')
    [@scenario[:student], @scenario[:assistant], other_teacher].each do |user|
      clear_cookies
      login_as(user)
      original = @assessment.values.dup
      %w[open_evaluation open_feedback close_feedback].each do |action|
        schedule(action)
        expect(last_response.status).to eq(403)
        expect(@assessment.values).to eq(original)
      end
      get "/assessment/#{@assessment[:id]}"
      expect(last_response.body).not_to include('/schedule/open_evaluation')
    end
  end

  it 'shows the three buttons to the course administrator' do
    login_as(@scenario[:teacher])
    get "/assessment/#{@assessment[:id]}"
    %w[open_evaluation open_feedback close_feedback].each do |action|
      expect(last_response.body).to include("/schedule/#{action}")
    end
  end
end
