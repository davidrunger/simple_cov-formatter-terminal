# frozen_string_literal: true

module SpecToAppMaps
  # rubocop:disable Lint/OrAssignmentToConstant
  SPEC_TO_APP_DEFAULT_MAP ||= {
    %r{\Aspec/lib/} => 'lib/',
    %r{\Aspec/controllers/admin/(.*)_controller_spec.rb} => 'app/admin/\1.rb',
    %r{
      \Aspec/
      (
      actions|
      channels|
      controllers|
      decorators|
      helpers|
      mailboxes|
      mailers|
      models|
      policies|
      serializers|
      views|
      workers
      )
      /
    }x => 'app/\1/',
  }.freeze
  SPEC_TO_GEM_DEFAULT_MAP ||= {
    %r{\Aspec/} => 'lib/',
  }.freeze
  DEFAULT_UNMAPPABLE_SPEC_REGEXES ||= [
    %r{\Aspec/features/},
  ].freeze
  # rubocop:enable Lint/OrAssignmentToConstant
end
