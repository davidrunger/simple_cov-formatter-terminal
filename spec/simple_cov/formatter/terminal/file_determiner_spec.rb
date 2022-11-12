# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::FileDeterminer) do
  subject(:file_determiner) { SimpleCov::Formatter::Terminal::FileDeterminer.new }

  describe '#spec_to_app_file_map' do
    subject(:spec_to_app_file_map) { file_determiner.spec_to_app_file_map }

    it 'returns the default_spec_to_app_map' do
      expect(spec_to_app_file_map).
        to eq(SimpleCov::Formatter::Terminal::SpecToAppMapping.default_spec_to_app_map)
    end
  end

  describe '#targeted_application_file' do
    subject(:targeted_application_file) { file_determiner.send(:targeted_application_file) }

    context 'when a SIMPLECOV_TARGET_FILE environment variable is present' do
      before do
        expect(file_determiner).
          to receive(:puts).
          with(/Determined.*from SIMPLECOV_TARGET_FILE/)
      end

      around do |example|
        ClimateControl.modify(SIMPLECOV_TARGET_FILE: specified_target_file) do
          example.run
        end
      end

      let(:specified_target_file) { 'path/to_a/great_file.rb' }

      it 'returns the specified file' do
        expect(targeted_application_file).to eq(specified_target_file)
      end
    end

    context 'when a SIMPLECOV_TARGET_FILE env var is not present' do
      before do
        expect(SimpleCov::Formatter::Terminal::RSpecIntegration).
          to receive(:executed_spec_files).
          at_least(:once).
          and_return([executed_spec_file])
      end

      context 'when run in a non-gem project' do
        before do
          expect(SimpleCov::Formatter::Terminal::RailsAwareness).
            to receive(:rails?).
            and_return(true)
          allow(file_determiner).
            to receive(:spec_to_app_file_map).
            and_return(SimpleCov::Formatter::Terminal::SpecToAppMapping.default_spec_to_app_map)
        end

        context 'when the executed spec file is an admin controller test' do
          let(:executed_spec_file) { 'spec/controllers/admin/csp_reports_controller_spec.rb' }

          it 'returns the correct Active Admin file' do
            expect(targeted_application_file).to eq('app/admin/csp_reports.rb')
          end
        end

        context 'when the executed spec file is a feature test' do
          let(:executed_spec_file) { 'spec/features/home_spec.rb' }

          it 'returns nil' do
            expect(targeted_application_file).to eq(nil)
          end
        end

        context 'when the executed spec file is not matched by any regex' do
          let(:executed_spec_file) { 'spec/dont_know/how_to/map_this_spec.rb' }

          it 'raises an error' do
            expect { targeted_application_file }.
              to raise_error(/Could not map executed spec file .* to application file!/)
          end
        end
      end
    end
  end
end
