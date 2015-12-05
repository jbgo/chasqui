shared_examples 'a queue adapter' do
  it 'implements bind' do
    method = described_class.instance_method :bind
    expect(method).not_to be_nil
    expect(method.arity).to eq(1)
  end

  it 'implements unbind' do
    method = described_class.instance_method :unbind
    expect(method).not_to be_nil
    expect(method.arity).to eq(1)
  end
end
