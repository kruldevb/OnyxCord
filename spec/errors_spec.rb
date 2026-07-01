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

  describe OnyxCord::Errors::HTTPError do
    it 'keeps HTTP diagnostics' do
      error = described_class.new('bad', status: 400, code: 12, headers: { via: 'cf' }, route: 'POST /x', body: 'html')

      expect(error.status).to eq(400)
      expect(error.code).to eq(12)
      expect(error.headers).to eq(via: 'cf')
      expect(error.route).to eq('POST /x')
      expect(error.body).to eq('html')
    end
  end

  describe 'CodeError HTTP metadata' do
    it 'keeps status, route, headers and body' do
      error = OnyxCord::Errors::Unauthorized.new('nope', nil, status: 401, headers: { h: 'v' }, route: 'GET /me', body: '{"message":"nope"}')

      expect(error.status).to eq(401)
      expect(error.code).to eq(40_001)
      expect(error.route).to eq('GET /me')
      expect(error.headers).to eq(h: 'v')
      expect(error.body).to eq('{"message":"nope"}')
    end
  end
end
