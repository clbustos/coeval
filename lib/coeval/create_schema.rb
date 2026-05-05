# encoding: UTF-8

require 'digest/sha1'
require 'sequel'

Sequel.extension :migration

module Coeval
  class CreateSchema
    DEFAULT_AUTHORIZATIONS = %w[
      dashboard_view
      course_view
      course_admin
      assessment_view
      assessment_admin
      assessment_evaluate
      group_admin
      group_view
      message_edit
      message_view
      user_admin
      role_admin
      role_view
      reflection
    ].freeze

    ROLE_PERMITS = {
      'administrator' => DEFAULT_AUTHORIZATIONS,
      'teacher' => %w[
        dashboard_view
        course_view
        course_admin
        assessment_view
        assessment_admin
      ],
      'student' => %w[
        dashboard_view
        assessment_evaluate
      ],
      'guest' => %w[
        dashboard_view
        course_view
        assessment_view
      ]
    }.freeze

    def initialize(db = $db, root: File.expand_path('../..', __dir__))
      raise ArgumentError, 'Database connection is required' unless db

      @db = db
      @root = root
    end

    def migrate!
      Sequel::Migrator.run(@db, migrations_path)
      true
    end
    alias create! migrate!

    def seed_base_data!
      @db.transaction do
        udec_id = institution_id('Universidad de Concepción')
        create_roles!
        create_authorizations!
        assign_role_permits!

        admin_id = user_id_by_login('admin') || @db[:users].insert(
          login: 'admin',
          name: 'Admin',
          password: Digest::SHA1.hexdigest('admin'),
          role_id: 'administrator',
          active: true,
          language: 'es',
          email: 'coeval@test.com',
          institution_id: udec_id
        )

        group_id = if @db[:groups][id: 1]
                     1
                   else
                     @db[:groups].insert(
                       id: 1,
                       group_administrator: admin_id,
                       description: 'First group, just for demostration',
                       name: 'demo group'
                     )
                   end
        insert_group_user_if_missing(group_id, admin_id)
      end
      true
    end

    def seed_demo_data!(strict: true)
      paths = {
        criteria: File.join(@root, 'criterios.xlsx'),
        levels: File.join(@root, 'niveles.xlsx'),
        course_group: File.join(@root, 'curso_grupo_1.xlsx')
      }
      missing_files = paths.values.reject { |path| File.exist?(path) }
      if missing_files.any?
        raise ArgumentError, "Missing seed files: #{missing_files.join(', ')}" if strict

        return false
      end

      require 'rubyXL'

      @db.transaction do
        udec_id = institution_id('Universidad de Concepción')
        admin_id = user_id_by_login('admin')
        raise 'Base seed data must be created before demo data' unless admin_id

        course_id = find_or_insert(
          :courses,
          { name: 'Metodología de la Investigación' },
          name: 'Metodología de la Investigación',
          teacher_id: admin_id,
          institution_id: udec_id,
          active: true
        )

        assessment_id = seed_demo_assessment(course_id)
        seed_criteria(paths[:criteria], assessment_id)
        seed_levels(paths[:levels])
        seed_course_group(paths[:course_group], course_id, assessment_id, udec_id, admin_id)
      end
      true
    end

    private

    attr_reader :db

    def migrations_path
      File.join(@root, 'db', 'migrations')
    end

    def create_roles!
      {
        'administrator' => 'App administrator',
        'teacher' => 'Teacher',
        'student' => 'Student',
        'guest' => 'Guest'
      }.each do |id, description|
        find_or_insert(:roles, { id: id }, id: id, description: description)
      end
    end

    def create_authorizations!
      DEFAULT_AUTHORIZATIONS.each do |authorization|
        find_or_insert(:authorizations, { id: authorization }, id: authorization)
      end
    end

    def assign_role_permits!
      ROLE_PERMITS.each_pair do |role_id, authorizations|
        authorizations.each do |authorization_id|
          find_or_insert(
            :authorizations_roles,
            { authorization_id: authorization_id, role_id: role_id },
            authorization_id: authorization_id,
            role_id: role_id
          )
        end
      end
    end

    def institution_id(name)
      find_or_insert(:institutions, { name: name }, name: name)
    end

    def user_id_by_login(login)
      user = @db[:users][login: login]
      user && user[:id]
    end

    def insert_group_user_if_missing(group_id, user_id)
      find_or_insert(:groups_users, { group_id: group_id, user_id: user_id }, group_id: group_id, user_id: user_id)
    end

    def seed_demo_assessment(course_id)
      assessment = @db[:assessments][name: 'Coevaluación 1', course_id: course_id]
      return assessment[:id] if assessment

      now = Time.now
      @db[:assessments].insert(
        name: 'Coevaluación 1',
        course_id: course_id,
        active: true,
        start_time_evaluation: now - (60 * 60 * 24),
        end_time_evaluation: now + (60 * 60 * 24 * 30),
        start_time_feedback: now - (60 * 60 * 24),
        end_time_feedback: now + (60 * 60 * 24 * 60)
      )
    end

    def seed_criteria(path, assessment_id)
      rows_from_xlsx(path).each_with_index do |row, index|
        criterion_id = row['criterio_id'].to_s
        find_or_insert(
          :criteria,
          { id: criterion_id },
          id: criterion_id,
          name: row['criterio_nombre'],
          criterion_type: row['criterion_type']
        )
        find_or_insert(
          :assessment_criteria,
          { criterion_id: criterion_id, assessment_id: assessment_id },
          criterion_id: criterion_id,
          assessment_id: assessment_id,
          criterion_order: index + 1
        )
      end
    end

    def seed_levels(path)
      rows_from_xlsx(path).each do |row|
        find_or_insert(
          :criterion_levels,
          { criterion_id: row['criterio_id'].to_s, points: row['points'] },
          criterion_id: row['criterio_id'].to_s,
          points: row['points'],
          description: row['description']
        )
      end
    end

    def seed_course_group(path, course_id, assessment_id, institution_id, teacher_id)
      rows_from_xlsx(path).each do |row|
        next if row['email'].nil?

        student_id = seed_student(row, institution_id)
        find_or_insert(:student_courses, { course_id: course_id, student_id: student_id }, course_id: course_id, student_id: student_id)

        group_name = row['grupo'].to_s.strip
        next if group_name.empty?

        team_id = find_or_insert(
          :teams,
          { assessment_id: assessment_id, name: group_name },
          assessment_id: assessment_id,
          name: group_name,
          teacher_id: teacher_id
        )
        find_or_insert(:student_teams, { team_id: team_id, student_id: student_id }, team_id: team_id, student_id: student_id)
      end
    end

    def seed_student(row, institution_id)
      login = row['email'].to_s.strip
      existing_user = @db[:users][login: login]
      return existing_user[:id] if existing_user

      @db[:users].insert(
        registration_code: row['matricula'].to_s.strip,
        name: row['nombre'].to_s.strip,
        login: login,
        email: login,
        role_id: 'student',
        language: 'es',
        institution_id: institution_id,
        active: true,
        password: Digest::SHA1.hexdigest(row['matricula'].to_s.strip)
      )
    end

    def rows_from_xlsx(path)
      workbook = RubyXL::Parser.parse(path)
      worksheet = workbook.worksheets[0]
      header = nil
      rows = []

      worksheet.each do |row|
        values = row.cells.map { |cell| cell && cell.value }
        if header.nil?
          header = values
        else
          rows << Hash[header.zip(values)]
        end
      end

      rows
    end

    def find_or_insert(table, lookup, values)
      row = @db[table][lookup]
      return row[:id] if row && row.key?(:id)
      return lookup.values.first if row

      @db[table].insert(values)
    end
  end
end
