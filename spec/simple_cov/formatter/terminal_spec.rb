# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.allocate }

  describe '#targeted_application_file' do
    subject(:targeted_application_file) { formatter.send(:targeted_application_file) }

    context 'when the executed spec file is an admin controller test' do
      before do
        SimpleCov::Formatter::Terminal.executed_spec_file =
          'spec/controllers/admin/csp_reports_controller_spec.rb'
      end

      it 'returns the correct Active Admin file' do
        expect(targeted_application_file).to eq('app/admin/csp_reports.rb')
      end
    end
  end
end
