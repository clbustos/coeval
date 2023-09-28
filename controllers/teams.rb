# Coeval
# https://github.com/clbustos/coeval
# Copyright (c) 2023, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information


# @!group Teams


get '/teams' do
  halt 403 unless (auth_to('assessment_view'))

  @teams=Team.order(:assessment_id, :name)

  haml :teams, escape_html: false
end

get '/team/:id' do |id|
  halt 403 unless (auth_to('assessment_view'))
  @user=User[session["user_id"]]
  @team=Team[id]
  raise Coeval::NoTeamIdError, id if !@team
  haml "assessments/team".to_sym, escape_html: false
end

# @!endgroup
