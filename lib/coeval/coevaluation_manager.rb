# Copyright (c) 2023, Claudio Bustos Navarrete
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

module Coeval
  # This class manage a specific assessment between two users.
  # Verifies that the assessment could be performed, updates the assessment in database once performed,
  # and validates if the assessment is complete

  class  CoevaluationManager
    attr_reader :result
    attr_reader :student_assessment
    attr_reader :structure
    attr_reader :student_criteria

    def initialize(assessment, student_from, student_to)
      @assessment = assessment
      @assessment_id = assessment[:id]
      @student_from = student_from
      @student_from_id = student_from[:id]
      @student_to = student_to
      @student_to_id = student_to[:id]
      @result = Result.new
    end

    def log_error(message, extra_info = nil)
      @result.error("#{::I18n::t(message)}. Assessment:#{@assessment_id},
                    student_from:#{@student_from[:name]},
                    student_to:#{@student_to[:name]}  #{extra_info}")
    end
    def log_success(message, extra_info = nil)
      @result.success("#{::I18n::t(message)}. Assessment:#{@assessment_id},
                    student_from:#{@student_from[:name]},
                    student_to:#{@student_to[:name]}  #{extra_info}")
    end

    def valid?
      unless @assessment.are_student_from_same_team?(@student_from, @student_to)
        log_error(:users_not_same_team, :error)
        return false
      end

      @team_id = Team.team_id_of_student_assessment(@student_from_id, @assessment_id)
      # Retrieve information for the evaluation
      @student_assessment = StudentAssessment.find_or_create(team_id: @team_id,
                                                             student_from: @student_from_id,
                                                             student_to: @student_to_id)
      @structure = @assessment.criteria_structure
      @criteria_h = Criterion.where(:id=>AssessmentCriterion.where(assessment_id:@assessment_id).map {
        |v|v[:criterion_id]}).to_hash(:id)
      #$log.info(@criteria_h)

      @student_criteria = AssessmentResponse.where(student_assessment_id: @student_assessment[:id]).to_hash(:criterion_id,
                                                                                                            :response_value)
      #$log.info(@student_criteria)
      return true
    end
    def update_assessment(newdata)
      correct=true
      $db.transaction do
        @criteria_h.each_pair do |criterion,c_data|
          if not newdata[criterion].nil? and newdata[criterion].strip!=""
            dd=newdata[criterion].strip
            asr1=AssessmentResponse.find_or_create(student_assessment_id: @student_assessment[:id],
                                              :criterion_id=>criterion)
            if c_data[:criterion_type]=="ordered_levels"
              dd=dd.to_i
            end
            asr1.update(value:dd)
          end
        end
      end

      if correct
        @student_assessment.update(saved:true)
        log_success('coevaluation_manager.update_data_successful')
      else
        log_error('coevaluation_manager.update_evalution_error')
      end
      correct

    end
    # Check if all fields are complete, and make complete the assessment
    def validate_complete_assessment
      if @student_assessment[:complete]
        return true
      else
        ar=AssessmentResponse.where(student_assessment_id: @student_assessment[:id],
                                    criterion_id: @criteria_h.keys())

        if ar.count<@criteria_h.keys.length
          log_error('coevaluation_manager.assessment_incomplete')
          return false
        else
          student_assessment.update(complete:true, sent:DateTime.now)
          log_success('coevaluation_manager.assessment_complete')
        end

      end

    end
  end
end