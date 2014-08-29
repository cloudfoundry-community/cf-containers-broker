# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
require 'spec_helper'

describe Credentials do
  let(:subject) { described_class.new(attrs) }
  let(:attrs) {
    {
      'username' => {
        'key' => username_key,
        'value' => username_value,
      },
      'password' => {
        'key' => password_key,
        'value' => password_value,
      },
      'dbname' => {
        'key' => dbname_key,
        'value' => dbname_value,
      },
      'uri' => {
        'prefix' => uri_prefix,
        'port' => uri_port,
      },
    }
  }
  let(:username_key) { 'SERVICE_USERNAME' }
  let(:username_value) { 'MY-USERNAME' }
  let(:password_key) { 'SERVICE_PASSWORD' }
  let(:password_value) { 'MY-PASSWORD' }
  let(:dbname_key) { 'SERVICE_DBNAME' }
  let(:dbname_value) { 'MY-PASSWORD' }
  let(:uri_prefix) { 'myprefix' }
  let(:uri_port) { '1234/tcp' }
  let(:guid) { 'guid' }
  let(:md5_base64) { '0123456789ABCDEFGHIJK'}

  describe '#initialize' do
    it 'sets the attributes correctly' do
      expect(subject.credentials).to eq(attrs)
    end
  end

  describe '#username_key' do
    it 'returns the username.key' do
      expect(subject.username_key).to eq(username_key)
    end

    context 'when username.key is not set' do
      let(:username_key) { nil }

      it 'returns nil' do
        expect(subject.username_key).to be_nil
      end
    end
  end

  describe '#username_value' do
    it 'returns the username.value' do
      expect(subject.username_value(guid)).to eq(username_value)
    end

    context 'when username.value is not set' do
      let(:username_value) { nil }

      it 'returns the 1st 16 chars of the guid MD5 digest in lowercase' do
        expect(Digest::MD5).to receive(:base64digest).with("USER-#{guid}").and_return(md5_base64)
        expect(subject.username_value(guid)).to eql(md5_base64[0...16].downcase)
      end
    end
  end

  describe '#password_key' do
    it 'returns the password.key' do
      expect(subject.password_key).to eq(password_key)
    end

    context 'when username.key is not set' do
      let(:password_key) { nil }

      it 'returns nil' do
        expect(subject.password_key).to be_nil
      end
    end
  end

  describe '#password_value' do
    it 'returns the password.value' do
      expect(subject.password_value(guid)).to eq(password_value)
    end

    context 'when password.value is not set' do
      let(:password_value) { nil }

      it 'returns the 1st 16 chars of the guid MD5 digest in lowercase' do
        expect(Digest::MD5).to receive(:base64digest).with("PWD-#{guid}").and_return(md5_base64)
        expect(subject.password_value(guid)).to eql(md5_base64[0...16].downcase)
      end
    end
  end

  describe '#dbname_key' do
    it 'returns the dbname.key' do
      expect(subject.dbname_key).to eq(dbname_key)
    end

    context 'when dbname.key is not set' do
      let(:dbname_key) { nil }

      it 'returns nil' do
        expect(subject.dbname_key).to be_nil
      end
    end
  end

  describe '#dbname_value' do
    it 'returns the dbname.value' do
      expect(subject.dbname_value(guid)).to eq(dbname_value)
    end

    context 'when dbname.value is not set' do
      let(:dbname_value) { nil }

      it 'returns the 1st 16 chars of the guid MD5 digest in lowercase' do
        expect(Digest::MD5).to receive(:base64digest).with("DB-#{guid}").and_return(md5_base64)
        expect(subject.dbname_value(guid)).to eql(md5_base64[0...16].downcase)
      end
    end
  end

  describe '#uri_prefix' do
    it 'returns the uri.prefix' do
      expect(subject.uri_prefix).to eq(uri_prefix)
    end

    context 'when uri.prefix is not set' do
      let(:uri_prefix) { nil }

      it 'returns nil' do
        expect(subject.uri_prefix).to be_nil
      end
    end
  end

  describe '#uri_port' do
    it 'returns the uri.port' do
      expect(subject.uri_port).to eq(uri_port)
    end

    context 'when uri.port is not set' do
      let(:uri_port) { nil }

      it 'returns nil' do
        expect(subject.uri_port).to be_nil
      end
    end
  end

  describe '#to_hash' do
    let(:hostname) { 'hostname' }
    let(:host_port) { '5678' }
    let(:ports) { { '1234/tcp' => host_port } }
    let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}:#{host_port}/#{dbname_value}" }
    let(:credentials_hash) { subject.to_hash(guid, hostname, ports) }

    it 'contains the correct values' do
      expect(credentials_hash.fetch('hostname')).to eq(hostname)
      expect(credentials_hash.fetch('port')).to eq(host_port)
      expect(credentials_hash.fetch('ports')).to eq(ports)
      expect(credentials_hash.fetch('username')).to eq(username_value)
      expect(credentials_hash.fetch('password')).to eq(password_value)
      expect(credentials_hash.fetch('dbname')).to eq(dbname_value)
      expect(credentials_hash.fetch('uri')).to eq(uri)
    end

    context 'when uri.port is set' do
      let(:uri_port) { '1234/tcp' }

      context 'and there is no exposed ports' do
        let(:ports) { {} }
        let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}/#{dbname_value}" }

        it 'should not return ports field' do
          expect(credentials_hash).to_not include('ports')
        end

        it 'should not return port field' do
          expect(credentials_hash).to_not include('port')
        end

        it 'uri should not contain a port' do
          expect(credentials_hash.fetch('uri')).to eq(uri)
        end
      end

      context 'and there is only one exposed port' do
        let(:ports) { { '1234/tcp' => host_port } }
        let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}:#{host_port}/#{dbname_value}" }

        it 'should return ports field' do
          expect(credentials_hash.fetch('ports')).to eq(ports)
        end

        it 'should return port field' do
          expect(credentials_hash.fetch('port')).to eq(host_port)
        end

        it 'uri should not contain a port' do
          expect(credentials_hash.fetch('uri')).to eq(uri)
        end

        context 'but is not the same as uri.port' do
          let(:uri_port) { '9012/tcp' }
          let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}/#{dbname_value}" }

          it 'should not return port field' do
            expect(credentials_hash).to_not include('port')
          end

          it 'uri should not contain a port' do
            expect(credentials_hash.fetch('uri')).to eq(uri)
          end
        end
      end

      context 'and there is more than one exposed port' do
        let(:ports) {
          {
            '1234/tcp' => host_port,
            '5678/tcp' => '99999',
          }
        }
        let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}:#{host_port}/#{dbname_value}" }

        it 'should return ports field' do
          expect(credentials_hash.fetch('ports')).to eq(ports)
        end

        it 'should return port field' do
          expect(credentials_hash.fetch('port')).to eq(host_port)
        end

        it 'uri should contain a port' do
          expect(credentials_hash.fetch('uri')).to eq(uri)
        end

        context 'but none matches uri.port' do
          let(:uri_port) { '9012/tcp' }
          let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}/#{dbname_value}" }

          it 'should not return port field' do
            expect(credentials_hash).to_not include('port')
          end

          it 'uri should not contain a port' do
            expect(credentials_hash.fetch('uri')).to eq(uri)
          end
        end
      end
    end

    context 'when uri.port is not set' do
      let(:uri_port) { nil }

      context 'and there is no exposed ports' do
        let(:ports) { {} }
        let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}/#{dbname_value}" }

        it 'should not return ports field' do
          expect(credentials_hash).to_not include('ports')
        end

        it 'should not return port field' do
          expect(credentials_hash).to_not include('port')
        end

        it 'uri should not contain a port' do
          expect(credentials_hash.fetch('uri')).to eq(uri)
        end
      end

      context 'and there is only one exposed port' do
        let(:ports) { { '1234/tcp' => host_port } }
        let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}:#{host_port}/#{dbname_value}" }

        it 'should return ports field' do
          expect(credentials_hash.fetch('ports')).to eq(ports)
        end

        it 'should return port field' do
          expect(credentials_hash.fetch('port')).to eq(host_port)
        end

        it 'uri should contain a port' do
          expect(credentials_hash.fetch('uri')).to eq(uri)
        end
      end

      context 'and there is more than one exposed port' do
        let(:ports) {
          {
            '1234/tcp' => host_port,
            '5678/tcp' => '99999',
          }
        }
        let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}/#{dbname_value}" }

        it 'should return ports field' do
          expect(credentials_hash.fetch('ports')).to eq(ports)
        end

        it 'should not return port field' do
          expect(credentials_hash).to_not include('port')
        end

        it 'uri should not contain a port' do
          expect(credentials_hash.fetch('uri')).to eq(uri)
        end
      end
    end

    context 'when username.key is not set' do
      let(:username_key) { nil }
      let(:uri) { "#{uri_prefix}://#{hostname}:#{host_port}/#{dbname_value}" }

      it 'does not return username field' do
        expect(credentials_hash).to_not include('username')
      end

      it 'uri does not contain username:password' do
        expect(credentials_hash.fetch('uri')).to eq(uri)
      end
    end

    context 'when password.key is not set' do
      let(:password_key) { nil }
      let(:uri) { "#{uri_prefix}://#{username_value}@#{hostname}:#{host_port}/#{dbname_value}" }

      it 'does not return password field' do
        expect(credentials_hash).to_not include('password')
      end

      it 'uri does not contain password' do
        expect(credentials_hash.fetch('uri')).to eq(uri)
      end
    end

    context 'when dbname.key is not set' do
      let(:dbname_key) { nil }
      let(:uri) { "#{uri_prefix}://#{username_value}:#{password_value}@#{hostname}:#{host_port}" }

      it 'does not return dbname field' do
        expect(credentials_hash).to_not include('dbname')
      end

      it 'uri does not contain dbname' do
        expect(credentials_hash.fetch('uri')).to eq(uri)
      end
    end

    context 'when uri.prefix is not set' do
      let(:uri_prefix) { nil }

      it 'does not return dbname field' do
        expect(credentials_hash).to_not include('uri')
      end
    end
  end
end
