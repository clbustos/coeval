# Copyright (c) 2016-2026, Claudio Bustos Navarrete
# Licensed BSD 3-Clause License

# List of institutions
get '/admin/institutions' do
  halt_unless_auth('user_admin')
  @institutions = Institution.order(:name)
  haml 'admin/institutions'.to_sym, escape_html: false
end

# Form to create an institution
get '/institution/new' do
  halt_unless_auth('user_admin')
  @institution = Institution.new
  haml 'admin/institution_edit'.to_sym, escape_html: false
end

# Form to edit an institution
get '/institution/:id/edit' do |id|
  halt_unless_auth('user_admin')
  @institution = Institution[id]
  return 404 if @institution.nil?

  haml 'admin/institution_edit'.to_sym, escape_html: false
end

# Create or update an institution
post '/institution/update' do
  halt_unless_auth('user_admin')
  institution_id = params['institution_id']
  name = params['name'].to_s.strip

  if name.empty?
    add_message(t(:institution_without_name), :error)
    redirect back
  end

  duplicate = Institution.where(name: name)
  duplicate = duplicate.exclude(id: institution_id.to_i) unless institution_id.to_s.empty?
  unless duplicate.empty?
    add_message(t(:Exists_another_institution_with_that_name), :error)
    redirect back
  end

  if institution_id.to_s.empty?
    Institution.create(name: name)
  else
    institution = Institution[institution_id]
    return 404 if institution.nil?
    institution.update(name: name)
  end

  redirect '/admin/institutions'
end

# Delete an unused institution
post '/institution/:id/delete' do |id|
  halt_unless_auth('user_admin')
  institution = Institution[id]
  return 404 if institution.nil?

  if User.where(institution_id: institution.id).empty? && Course.where(institution_id: institution.id).empty?
    institution.delete
    add_message(t(:Institution_deleted_name, institution: institution.name))
  else
    add_message(t(:Institution_in_use), :error)
  end

  redirect '/admin/institutions'
end
