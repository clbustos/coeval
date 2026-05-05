# Copyright (c) 2016-2023, Claudio Bustos Navarrete
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Provides information to user dashboard
class UserDashboardInfo
  attr_reader :user
  def initialize(user)
    @user=user
    #@sr_active=user.systematic_reviews.where(:active=>true)
  end
  def is_administrator_assessment?(assessment)
    raise Coeval::NoAssessmentIdError, nil unless assessment
    assessment.teacher[:id]==self.user[:id]
  end
  def is_evaluation_complete?(assessment)
    res=$db["SELECT SUM(saved) as guardados, COUNT(*) as n FROM assessments_results_raw WHERE assessment_id=? AND student_to=?",
        assessment[:id], @user[:id]].first
    res[:guardados]==res[:n]
  end

  def active_teacher_courses
    lead_courses=Course.where(teacher_id:@user[:id], active:true).all.map do |course|
      {course:course, role: :Lead_teacher}
    end

    assistant_course_ids=AssistantTeacher.where(teacher_id:@user[:id]).map(:course_id)
    assistant_courses=Course.where(id:assistant_course_ids, active:true).all.map do |course|
      {course:course, role: :Assistant_teacher}
    end

    (lead_courses + assistant_courses)
      .uniq {|course_data| course_data[:course][:id]}
      .sort_by {|course_data| course_data[:course][:name].to_s.downcase}
  end


  def quantitative_assessment(assessment, type)
    raise Coeval::NoAssessmentIdError, nil unless assessment

    team_id=Team.team_id_of_student_assessment( self.user[:id],assessment[:id])
    team_o=Team[team_id]
    return nil unless team_o
    rp=team_o.response_pivot(type)

    student_pivot=rp.pivot[self.user[:id]]
    return nil unless student_pivot

    criteria_names=rp.criteria.inject({}) do |ac, criterion|
      ac[criterion[:criterion_id]]=criterion[:criterion_name]
      ac
    end
    named_pivot=student_pivot.inject({}) do |ac, criterion_data|
      criterion_id, value=criterion_data
      ac[criteria_names.fetch(criterion_id, criterion_id)]=value
      ac
    end

    named_pivot.merge(total: rp.calculate_student_total[self.user[:id]])
  end
  def qualitative_assessment(assessment)
    raise Coeval::NoAssessmentIdError, nil unless assessment

    assessment.open_ended_responses({student_to:@user[:id]})
  end

  def is_member?(assessment)
    raise Exception("TODO")
  end
  def get_users_to_assess(assessment)
    raise Coeval::NoAssessmentIdError, nil unless assessment

    team_id=Team.team_id_of_student_assessment( self.user[:id],assessment[:id])
    students_team=StudentTeam.where(team_id:team_id).map {|v| v[:student_id]}
    students_to=User.where(:id=>students_team).to_hash(:id, :name)
    student_assessments=StudentAssessment.where(:team_id=>team_id, :student_from=>self.user[:id]).to_hash(:student_to)
    #$log.info(student_assessments)

    out=students_to.inject({}) do |ac,v|
      student_id=v[0]
      student_name=v[1]
      sa_local=student_assessments.fetch(student_id,{:saved=>false,:complete=>false, :sent=>nil})

      ac[student_id]={name:student_name,
                      saved: sa_local[:saved],
                      complete: sa_local[:complete],
                      sent: sa_local[:sent]
      }
      ac
    end

    out
  end
end
