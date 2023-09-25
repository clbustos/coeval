# Buhos
# https://github.com/clbustos/buhos
# Copyright (c) 2016-2023, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information
#

# @!group Systematic review message


post '/message/:m_id/seen_by/:user_id' do |m_id, user_id|
  halt_unless_auth('message_edit')
  ms=Message.where(:id=>m_id, :user_to=>user_id)
  if ms
    ms.update(:viewed=>true)
  end
  return 200
end

# @!endgroup

# @!group Personal messages

# Send a reply to a message
post '/message_per/:m_id/reply' do |m_id|
  halt_unless_auth('message_edit')
  m_per=Message[m_id]
  @user_id=params['user_id']
  @user=User[@user_id]


  raise Buhos::NoUserIdError, @user_id if !@user
  raise Buhos::NoMessageIdError, m_id     if !m_per

  halt 403 unless is_session_user(@user_id)


  @subject=params['subject'].chomp
  @text=params['text'].chomp
  $db.transaction(:rollback=>:reraise) do
    id=Message.insert(:user_from=>@user_id, :user_to=>m_per.user_from , :reply_to=>m_per.id, :time=>DateTime.now(), :subject=>@subject, :text=>@text, :viewed=>false)
    add_message(t("messages.add_reply_to", subject: m_per.subject))
  end
  redirect back

end

# @!endgroup