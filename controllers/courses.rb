# Coeval
# https://github.com/clbustos/coeval
# Copyright (c) 2023, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information


# @!group Courses


get '/courses' do
  halt 403 unless (auth_to('course_view'))

  @courses=Course.order(:active, :name)
  haml :courses, escape_html: false
end

get '/course/:id' do |id|
  halt 403 unless (auth_to('course_view') or auth_to('assessment_evaluate'))

  @course=Course[id]
  haml "courses/view".to_sym, escape_html: false
end

# @!endgroup
