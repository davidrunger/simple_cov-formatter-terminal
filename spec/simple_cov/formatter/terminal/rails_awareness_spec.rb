# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::RailsAwareness) do
  describe '::rails?' do
    subject(:rails?) do
      SimpleCov::Formatter::Terminal::RailsAwareness.rails?
    end

    context 'when a Rails constant is defined' do
      before { stub_const('Rails', Class.new) }

      it 'returns true' do
        expect(rails?).to eq(true)
      end
    end

    context 'when a Rails constant is not defined' do
      before { expect(defined?(Rails)).to eq(nil) }

      it 'returns false' do
        expect(rails?).to eq(false)
      end
    end
  end
end
