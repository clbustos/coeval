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

require_relative 'sinatra/i18n'



module Coeval
  # @!group Error Codes: Connection problems


  # @!endgroup
  # @!group Error Codes: No Object

  # Exception when no systematic review id exists
  class NoAssessmentIdError < StandardError ; end

  class NoCourseIdError < StandardError ; end


  # Exception when no user id exists
  class NoUserIdError < StandardError ; end



  # Exception when no group id exists

  class NoGroupIdError < StandardError ; end

  # Exception when no role id exists

  class NoRoleIdError < StandardError ; end
  # @!endgroup
end


module Sinatra
  # Extensions to Sinatra, that shows personalized errors for Buhos exceptions
  #
  module CustomErrors
    def self.registered(app)

      app.error Coeval::NoAssessmentIdError do
        status 404
        ::I18n::t("error.no_code", object_name: ::I18n::t(:Assessment), code:env['sinatra.error'].message)
      end
      app.error Coeval::NoCourseIdError do
        status 404
        ::I18n::t("error.no_code", object_name: ::I18n::t(:Course), code:env['sinatra.error'].message)
      end
      app.error Coeval::NoUserIdError do
        status 404
        ::I18n::t("error.no_code", object_name: ::I18n::t(:User), code:env['sinatra.error'].message)
      end

      app.error Coeval::NoGroupIdError do
        status 404
        ::I18n::t("error.no_code", object_name: ::I18n::t(:Group), code:env['sinatra.error'].message)
      end

      app.error Coeval::NoRoleIdError do
        status 404
        ::I18n::t("error.no_code", object_name: ::I18n::t(:Role), code:env['sinatra.error'].message)
      end

    end
  end
  register CustomErrors
end