# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::GemAwareness) do
  describe '::gem?' do
    subject(:gem?) do
      SimpleCov::Formatter::Terminal::GemAwareness.send(:gem?)
    end

    context 'when there is a gemspec file' do # this context uses this gem's actual .gemspec file
      it 'returns true' do
        expect(gem?).to eq(true)
      end
    end
  end
end
