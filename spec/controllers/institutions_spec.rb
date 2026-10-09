# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'Institutions controller' do
  let(:administrator) { create_user(login: 'institution_admin', role_id: 'administrator') }

  before { login_as(administrator) }

  it 'lists institutions for administrators' do
    get '/admin/institutions'

    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Universidad de Concepción')
  end

  it 'renders the institution creation form' do
    get '/institution/new'

    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("name='name'")
  end

  it 'creates and updates an institution' do
    post '/institution/update', name: 'Universidad Nueva'

    expect(last_response).to be_redirect
    institution = Institution[name: 'Universidad Nueva']
    expect(institution).not_to be_nil

    post '/institution/update', institution_id: institution.id, name: 'Universidad Actualizada'

    expect(last_response).to be_redirect
    expect(Institution[institution.id].name).to eq('Universidad Actualizada')
  end

  it 'rejects an empty institution name' do
    post '/institution/update', name: '  '

    expect(last_response).to be_redirect
    expect(Institution.where(name: '').count).to eq(0)
  end

  it 'deletes an institution that is not in use' do
    institution = Institution.create(name: 'Institución temporal')

    post "/institution/#{institution.id}/delete"

    expect(last_response).to be_redirect
    expect(Institution[institution.id]).to be_nil
  end

  it 'does not allow a non-administrator to list institutions' do
    clear_cookies
    login_as(create_user(login: 'institution_student', role_id: 'student'))

    get '/admin/institutions'

    expect(last_response.status).to eq(403)
  end
end
