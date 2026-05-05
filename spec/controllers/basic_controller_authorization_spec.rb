# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Basic controller authorization' do
  it 'protects assessments index' do
    user = create_user(login: 'assessment_student', role_id: 'student')
    login_as(user)

    get '/assessments'

    expect(last_response.status).to eq(403)
  end

  it 'protects teams index' do
    user = create_user(login: 'team_student', role_id: 'student')
    login_as(user)

    get '/teams'

    expect(last_response.status).to eq(403)
  end

  it 'protects admin users routes' do
    user = create_user(login: 'user_student', role_id: 'student')
    login_as(user)

    get '/admin/users'

    expect(last_response.status).to eq(403)
  end

  it 'protects admin groups routes' do
    user = create_user(login: 'group_student', role_id: 'student')
    login_as(user)

    get '/admin/groups'

    expect(last_response.status).to eq(403)
  end

  it 'protects admin roles routes' do
    user = create_user(login: 'role_student', role_id: 'student')
    login_as(user)

    get '/admin/roles'

    expect(last_response.status).to eq(403)
  end

  it 'protects reflection routes' do
    user = create_user(login: 'reflection_student', role_id: 'student')
    login_as(user)

    get '/admin/routes'

    expect(last_response.status).to eq(403)
  end

  it 'protects message mutation routes' do
    user = create_user(login: 'message_student', role_id: 'student')
    login_as(user)

    post "/message/1/seen_by/#{user[:id]}"

    expect(last_response.status).to eq(403)
  end
end
