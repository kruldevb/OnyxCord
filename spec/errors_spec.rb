# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Errors do
  describe 'Code' do
    it 'should create a class without errors' do
      OnyxCord::Errors.Code(10_000)
    end

    describe 'the created class' do
      it 'should contain the correct code' do
        classy = OnyxCord::Errors.Code(10_001)
        expect(classy.code).to eq(10_001)
      end

      it 'should create an instance with the correct code' do
        classy = OnyxCord::Errors.Code(10_002)
        error = classy.new 'random message'
        expect(error.code).to eq(10_002)
        expect(error.message).to eq 'random message'
      end
    end
  end

  describe 'error_class_for' do
    it 'should return the correct class for code 40001' do
      classy = OnyxCord::Errors.error_class_for(40_001)
      expect(classy).to be(OnyxCord::Errors::Unauthorized)
    end
  end

  describe OnyxCord::Errors::Unauthorized do
    it 'should exist' do
      expect(OnyxCord::Errors::Unauthorized).to be_a(Class)
    end

    it 'should have the correct code' do
      instance = OnyxCord::Errors::Unauthorized.new('some message')
      expect(instance.code).to eq(40_001)
    end
  end
end
