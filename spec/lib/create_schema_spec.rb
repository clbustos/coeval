# encoding: UTF-8

require_relative '../spec_helper'

RSpec.describe Coeval::CreateSchema do
  let(:db) { Sequel.sqlite }
  let(:schema) { described_class.new(db) }

  after do
    db.disconnect
  end

  it 'applies all schema migrations to an empty database' do
    schema.migrate!

    expect(db.tables).to include(
      :roles,
      :users,
      :courses,
      :assessments,
      :assessment_responses,
      :assistant_teachers,
      :schema_info
    )
    expect(db[:schema_info].get(:version)).to eq(8)
    expect(db[:authorizations].where(id:'course_assistant_monitor').count).to eq(1)
  end

  it 'creates base seed data idempotently' do
    schema.migrate!

    2.times { schema.seed_base_data! }

    expect(db[:users].where(login: 'admin').count).to eq(1)
    expect(db[:roles].where(id: 'administrator').count).to eq(1)
    expect(db[:authorizations_roles].where(role_id: 'administrator').count).to eq(Coeval::CreateSchema::DEFAULT_AUTHORIZATIONS.length)
  end
end
