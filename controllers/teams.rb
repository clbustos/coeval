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
  @user_names=@team.users.to_hash(:id, :name)
  @gs=Coeval::GradingSystem.new(@team.assessment)


  raise Coeval::NoTeamIdError, id if !@team



  haml "assessments/team".to_sym, escape_html: false
end

get '/team/:id/student/:student_id' do |id, student_id|
  halt 403 unless (auth_to('assessment_view'))
  @user=User[session["user_id"]]
  @team=Team[id]
  @user_names=@team.users.to_hash(:id, :name)
  @student=User[student_id]
  @assessment=@team.assessment
  raise Coeval::NoTeamIdError, id if !@team
  raise Coeval::NoUserIdError, student_id if !@student



#  @gs=Coeval::GradingSystem.new(@team.assessment)

  @udi=UserDashboardInfo.new(@user)



  haml "assessments/student_in_team".to_sym, escape_html: false
end



# @!endgroup
