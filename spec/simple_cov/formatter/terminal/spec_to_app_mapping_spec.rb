# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::SpecToAppMapping) do
  describe '::default_spec_to_app_map' do
    subject(:default_spec_to_app_map) do
      SimpleCov::Formatter::Terminal::SpecToAppMapping.send(:default_spec_to_app_map)
    end

    context 'when within a gem' do
      it 'returns the SPEC_TO_GEM_DEFAULT_MAP' do
        expect(default_spec_to_app_map).
          to eq(SimpleCov::Formatter::Terminal::SpecToAppMapping::SPEC_TO_GEM_DEFAULT_MAP)
      end
    end

    context 'when not within a gem' do
      before do
        expect(SimpleCov::Formatter::Terminal::GemAwareness).
          to receive(:gem?).
          and_return(false)
      end

      it 'returns the SPEC_TO_GEM_DEFAULT_MAP' do
        expect(default_spec_to_app_map).
          to eq(SimpleCov::Formatter::Terminal::SpecToAppMapping::SPEC_TO_APP_DEFAULT_MAP)
      end
    end
  end
end
