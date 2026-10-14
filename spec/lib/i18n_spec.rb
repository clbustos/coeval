# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe 'I18n configuration' do
  it 'includes translated authorization labels' do
    expect(::I18n.t('auth.course_admin', locale: :es)).to eq('Curso: Admin')
    expect(::I18n.t('auth.course_admin', locale: :en)).to eq('Course: Admin')
  end

  it 'falls back to Spanish when a key is missing in the current locale' do
    ::I18n.locale = :en

    expect(::I18n.t(:New_scale)).to eq('Nueva escala')
  end

  it 'uses the current locale in the main layout html tag' do
    user = create_user(login: 'english_teacher', role_id: 'teacher')
    user.update(language: 'en')

    login_as(user)
    get '/courses'

    expect(last_response.body).to include("<html lang='en'>")
  end
end
