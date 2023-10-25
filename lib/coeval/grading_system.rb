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
  class GradingSystem
    def initialize(assesment)
      @grade_system=assesment[:grade_system]
      @parameter_1=assesment[:grade_parameter_1]
      @parameter_2=assesment[:grade_parameter_2]
    end
    def output(value)
      return "--" if value.nil?
      "#{self.grade(value)} (#{(value*100).round(0)}%)"
    end
    # In Chile, exams are typically graded using a system known as the "Chilean grading scale"
    # or "7-point grading scale." This scale assigns grades based on a 1 to 7 range,
    # where 1 is the lowest grade and 7 is the highest grade.
    # The scale is commonly used in educational institutions in Chile,
    # including schools and universities.
    # The first parameter of the class represents the exigence level,
    # as percentage
    # @param value a value from 0 to 1
    # @return a grade, between 1 and 7
    def grade_chilean(value)
      return "-not parameter 1-" unless @parameter_1
      nmin=1.0
      nmax=7.0
      napr=4.0
      exig=@parameter_1/100.0
      if value<exig
        res=(napr-nmin)*(value/exig) + nmin
      else
        res=(nmax-napr)*(value-exig)/(1-exig) + napr
      end
      res.round(1)
    end
    def grade(value)
      if @grade_system.nil? or value.nil?
        return nil
      else
        if @grade_system=="chilean"
          return self.grade_chilean(value)
        else
          raise "NOT IMPLEMENTED"
        end
      end
    end
  end
end