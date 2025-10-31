# frozen_string_literal: true
require 'spec_helper'
include Rack::Common
include Rack::PiLogger # IP blocking writes logs

describe Rack::Common do
  describe "ip blocking" do
    subject { ip_not_allowed(ips_to_block) }

    let(:ips_to_block) { nil }

    before do
      @ip_address = "192.168.0.1"
    end

    context "when the ip address is an exact match" do
      let(:ips_to_block) { @ip_address }

      it { is_expected.to be true }
    end

    context "when the ip address matches the regex" do
      let(:ips_to_block) { "/192.168.0.*/" }

      it { is_expected.to be true }
    end

    context "when the ip address exactly matches one of many" do
      let(:ips_to_block) { "192.168.0.3\n192.168.0.2\n192.168.0.1" }

      it { is_expected.to be true }
    end

    context "when the ip address matches none of many" do
      let(:ips_to_block) { "192.168.0.3\n192.168.0.2\n192.168.0.4" }

      it { is_expected.to be false }
    end

    context "when the ip address exactly matches one of many regexes" do
      let(:ips_to_block) { "/192.168.0.*/\n/192.168.1.*/\n/192.168.2.*/" }

      it { is_expected.to be true }
    end

    context "when the ip address matches none of many regexes" do
      let(:ips_to_block) { "/192.168.*.2/\n/192.168.1.*/\n/192.168.2.*/" }

      it { is_expected.to be false }
    end

    context "when no blocklist is specified" do
      let(:ips_to_block) { nil }

      it { is_expected.to be_nil }
    end

    context "when preview_mode" do
      let(:ips_to_block) { "192.168.0.1" }

      before do
        @preview_mode = true
      end

      after do
        @preview_mode = nil
      end

      it { is_expected.to be_nil }
    end

    context "when no IP address is specified" do
      let(:ips_to_block) { "/192.168.0.1/" }

      before do
        @old_ip_address = @ip_address
        @ip_address = nil
      end

      after do
        @ip_address = @old_ip_address
      end

      it { is_expected.to be_nil }
    end

    context "when an empty blocklist is specified" do
      let(:ips_to_block) { "" }

      it { is_expected.to be false }
    end
  end

  describe 'url without protocol' do
    it "returns a 403 if not a valid url" do
      expect(url_without_protocol('bla').first).to eq(403)
    end

    it "returns a 403 if it's not an http / https url" do
      expect(url_without_protocol('ftp://domain.com/bla').first).to eq(403)
    end

    it "correctly extracts the path of an http url" do
      expect(url_without_protocol('http://domain.com/bla')).to eq('domain.com/bla')
    end

    it "does not add a trailing slash" do
      expect(url_without_protocol('http://domain.com')).to eq('domain.com')
    end

    it "correctly extracts the path of an https url" do
      expect(url_without_protocol('https://www.domain.com/abc')).to eq('www.domain.com/abc')
    end

    it "correctly extracts the query string as well" do
      expect(url_without_protocol('http://www.domain.com/abc?a=1')).to eq('www.domain.com/abc?a=1')
    end

    it "correctly extracts the path of an http url with a port number" do
      expect(url_without_protocol('http://domain.com:8000/cart')).to eq('domain.com:8000/cart')
    end
  end

  describe 'valid_client_key?' do
    context 'when client_key is valid' do
      it 'returns true' do
        %w(client_key undefined_user nullable_section).each do |valid_client_key|
          expect(valid_client_key?(valid_client_key)).to be true
        end
      end
    end

    context 'when client_key is invalid' do
      it 'returns false' do
        [nil, "null", 'undefined', '  null', "undefined\n\r"].each do |invalid_client_key|
          expect(valid_client_key?(invalid_client_key)).to be false
        end
      end
    end
  end

  describe 'replace_inconvertible_characters' do
    subject { replace_inconvertible_characters(params)['query_key'] }

    let(:params) { {'query_key' => query_value} }

    context 'with inconvertible character' do
      let(:query_value) { String.new("abCD-123\xB2", encoding: "ASCII-8BIT") }

      it { is_expected.to eq 'abCD-123?' }
    end

    context 'with no inconvertible characters' do
      let(:query_value) { 'abCD-123' }

      it { is_expected.to eq 'abCD-123' }
    end

    context 'when query value is nil' do
      let(:query_value) { nil }

      it { is_expected.to be_nil }
    end

    context 'when query value is empty' do
      let(:query_value) { '' }

      it { is_expected.to eq '' }
    end

    context 'when query value is an hash' do
      let(:query_value) { {'foo' => '0', 'bar' => '1', 'baz' => '2'} }

      it { is_expected.to eq({'foo' => '0', 'bar' => '1', 'baz' => '2'}) }

      context 'with inconvertible character' do
        let(:query_value) { {'foo' => String.new("0\xB2", encoding: "ASCII-8BIT"), 'bar' => '1', 'baz' => '2'} }

        it { is_expected.to eq({'foo' => '0?', 'bar' => '1', 'baz' => '2'}) }
      end
    end

    context 'when query value is a nested hash' do
      let(:query_value) { {'foo' => {'a' => '0'}, 'bar' => '1', 'baz' => '2'} }

      it { is_expected.to eq({'foo' => {'a' => '0'}, 'bar' => '1', 'baz' => '2'}) }

      context 'with inconvertible character' do
        let(:query_value) { {'foo' => {'a' => String.new("0\xB2", encoding: "ASCII-8BIT")}, 'bar' => '1', 'baz' => '2'} }

        it { is_expected.to eq({'foo' => {'a' => '0?'}, 'bar' => '1', 'baz' => '2'}) }
      end
    end

    context 'when query value is an array' do
      let(:query_value) { [{'foo' => '1', 'bar' => '2'}, {'baz' => '3'}] }

      it { is_expected.to eq [{'foo' => '1', 'bar' => '2'}, {'baz' => '3'}] }

      context 'with inconvertible character' do
        let(:query_value) { [{'foo' => '1', 'bar' => String.new("2\xB2", encoding: "ASCII-8BIT")}, {'baz' => '3'}] }

        it { is_expected.to eq [{'foo' => '1', 'bar' => '2?'}, {'baz' => '3'}] }
      end
    end

    context 'when query value is a hash with array as value' do
      let(:query_value) { {'foo' => %w(1 2 3) } }

      it { is_expected.to eq({'foo' => %w(1 2 3)}) }

      context 'with inconvertible character' do
        let(:query_value) { {'foo' => [String.new("1\xB2", encoding: "ASCII-8BIT"), '2', '3'] } }

        it { is_expected.to eq({'foo' => %w(1? 2 3)}) }
      end
    end
  end

  describe 'parse_params' do
    describe 'replace inconvertible characters' do
      subject { parse_params['custom_data'] }

      before do
        allow(self).to receive(:log)

        @env = {
          'REQUEST_METHOD' => 'GET',
          'REQUEST_PATH' => '/serve',
          'QUERY_STRING' => query_string
        }
      end

      let(:query_string) { String.new("custom_data=%7B%22text%22%3A%22text+with+weird+characters\xB2%22%7D", encoding: "ASCII-8BIT") }

      it { is_expected.to eq '{"text":"text with weird characters?"}' }
    end
  end

  describe 'jsonp_response' do
    let(:response_object) { JSON.dump({ submission: { udid: '00000000-0000-4000-f000-000000000001' } }) }

    context 'when a callback is not there' do
      it 'returns a response object' do
        response = jsonp_response(nil, response_object)
        expect(response[0]).to eq 200 # TODO: Resolve magic numbers
        expect(response[2]).to eq [response_object]
      end
    end

    context 'when a callback is valid' do
      let(:valid_callback) { "window.PulseInsightsObject.jsonpCallbacks.request_#{callback_count}" }

      context 'when the callback count is a single digit' do
        let(:callback_count) { 3 }

        it 'returns that callback with a response object wrapped in it' do
          response = jsonp_response(valid_callback, response_object)
          expect(response[0]).to eq 200
          expect(response[2]).to eq ["#{valid_callback}(#{response_object});"]
        end
      end

      context 'when the callback count is double digits' do
        let(:callback_count) { 11 }

        it 'returns that callback with a response object wrapped in it' do
          response = jsonp_response(valid_callback, response_object)
          expect(response[0]).to eq 200
          expect(response[2]).to eq ["#{valid_callback}(#{response_object});"]
        end
      end
    end

    context 'when a callback is not valid' do
      it 'returns an error' do
        invalid_callback = 'alert(document.cookies);'
        response = jsonp_response(invalid_callback, response_object)
        expect(response[0]).to eq 400
        expect(response[2]).to eq ["Error: Parameter 'callback' invalid"]
      end
    end
  end
end
