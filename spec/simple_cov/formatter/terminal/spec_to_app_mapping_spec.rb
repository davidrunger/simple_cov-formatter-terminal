# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::SpecToAppMapping) do
  describe '::default_spec_to_app_map' do
    subject(:default_spec_to_app_map) do
      SimpleCov::Formatter::Terminal::SpecToAppMapping.send(:default_spec_to_app_map)
    end

    context 'when not within a Rails app' do
      before do
        expect(SimpleCov::Formatter::Terminal::RailsAwareness).
          to receive(:rails?).
          and_return(false)
      end

      it 'returns the SPEC_TO_GEM_DEFAULT_MAP' do
        expect(default_spec_to_app_map).
          to eq(SimpleCov::Formatter::Terminal::SpecToAppMapping::SPEC_TO_GEM_DEFAULT_MAP)
      end
    end

    context 'when within a Rails app' do
      before do
        expect(SimpleCov::Formatter::Terminal::RailsAwareness).
          to receive(:rails?).
          and_return(true)
      end

      it 'returns the SPEC_TO_RAILS_DEFAULT_MAP' do
        expect(default_spec_to_app_map).
          to eq(SimpleCov::Formatter::Terminal::SpecToAppMapping::SPEC_TO_RAILS_DEFAULT_MAP)
      end
    end
  end
end
