# encoding: UTF-8

Sequel.migration do
  up do
    unless self[:authorizations].where(id:'course_assistant_monitor').any?
      self[:authorizations].insert(
        id:'course_assistant_monitor',
        description:'Monitor every team in assigned courses as an assistant teacher'
      )
    end
  end

  down do
    self[:authorizations_roles].where(authorization_id:'course_assistant_monitor').delete
    self[:authorizations].where(id:'course_assistant_monitor').delete
  end
end
