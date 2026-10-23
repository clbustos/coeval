require_relative 'spec_helper'

RSpec.describe Coeval::TimeZone do
  it 'interprets course wall clocks independently of the server zone' do
    expect(described_class.parse('2026-01-15T12:00', 'America/Santiago').utc).to eq(Time.utc(2026, 1, 15, 15))
    expect(described_class.parse('2026-07-15T12:00', 'America/Santiago').utc).to eq(Time.utc(2026, 7, 15, 16))
  end

  it 'rejects ambiguous and nonexistent clock times' do
    expect { described_class.parse('2026-03-08T02:30', 'America/New_York') }.to raise_error(TZInfo::PeriodNotFound)
    expect { described_class.parse('2026-11-01T01:30', 'America/New_York') }.to raise_error(TZInfo::AmbiguousTime)
  end

  it 'inherits the system setting and allows a course override' do
    scenario = create_course_scenario
    course = scenario[:course]
    expect(course.timezone).to eq(described_class.default)
    course.update(timezone:'Asia/Tokyo')
    assessment = scenario[:assessment]
    assessment.update(start_time_evaluation:Time.utc(2026, 1, 15, 15))
    expect(assessment.refresh.formatted_datetime(:start_time_evaluation)).to eq('2026-01-16 00:00 +09:00 (Asia/Tokyo)')
  end
end
