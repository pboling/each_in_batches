require "spec_helper"

describe EachInBatches do
  it "has a version number" do
    expect(EachInBatches::VERSION).not_to be nil
  end

  it "can instantiate" do
    expect { EachInBatches::Batch.new }.to_not raise_error
  end
end
