# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::ResponseHelper do
  let(:helper_class) do
    Class.new do
      include DhanHQ::ResponseHelper
    end
  end
  let(:helper) { helper_class.new }

  describe "#parse_json" do
    it "parses valid JSON strings" do
      json_string = '{"key": "value"}'
      result = helper.send(:parse_json, json_string)
      expect(result).to eq({ key: "value" }.with_indifferent_access)
    end

    it "handles empty strings gracefully" do
      result = helper.send(:parse_json, "")
      expect(result).to eq({}.with_indifferent_access)
    end

    it "handles whitespace-only strings gracefully" do
      result = helper.send(:parse_json, "   ")
      expect(result).to eq({}.with_indifferent_access)
    end

    it "raises DataError for invalid JSON (non-empty, malformed)" do
      invalid_json = "not valid json"
      expect { helper.send(:parse_json, invalid_json) }
        .to raise_error(DhanHQ::DataError, /Failed to parse JSON response/)
    end

    it "logs error when JSON parsing fails" do
      invalid_json = "not valid json"
      expect(DhanHQ.logger).to receive(:error).with(/JSON parse error/)
      expect(DhanHQ.logger).to receive(:debug).with(/Failed to parse body/)
      expect { helper.send(:parse_json, invalid_json) }.to raise_error(DhanHQ::DataError)
    end

    it "handles hash input" do
      hash_input = { key: "value" }
      result = helper.send(:parse_json, hash_input)
      expect(result).to eq({ key: "value" }.with_indifferent_access)
    end

    it "handles array input" do
      array_input = [{ key: "value" }]
      result = helper.send(:parse_json, array_input)
      expect(result).to be_an(Array)
      expect(result.first).to eq({ key: "value" }.with_indifferent_access)
    end
  end

  describe "#handle_response" do
    let(:response) { instance_double(Faraday::Response, status: status, body: body) }

    context "with 200 status" do
      let(:status) { 200 }
      let(:body) { { success: true } }

      it "returns parsed JSON" do
        result = helper.send(:handle_response, response)
        expect(result).to eq({ success: true }.with_indifferent_access)
      end
    end

    context "with 202 status (Accepted)" do
      let(:status) { 202 }
      let(:body) { "" }

      it "returns accepted status hash" do
        result = helper.send(:handle_response, response)
        expect(result).to eq({ status: "accepted" }.with_indifferent_access)
      end
    end

    context "with error status" do
      let(:status) { 400 }
      let(:body) { { errorCode: "DH-905", errorMessage: "Invalid request" } }

      it "calls handle_error" do
        expect { helper.send(:handle_response, response) }
          .to raise_error(DhanHQ::InputExceptionError)
      end
    end
  end

  describe "#handle_error" do
    let(:response) { instance_double(Faraday::Response, status: status, body: body) }

    context "with mapped error code" do
      let(:status) { 401 }
      let(:body) { { errorCode: "DH-901", errorMessage: "Invalid authentication" } }

      it "raises appropriate error class" do
        expect { helper.send(:handle_error, response) }
          .to raise_error(DhanHQ::InvalidAuthenticationError, /DH-901/)
      end
    end

    context "with error code 807 (token expired)" do
      let(:status) { 401 }
      let(:body) { { errorCode: "807", errorMessage: "Token expired" } }

      it "raises TokenExpiredError" do
        expect { helper.send(:handle_error, response) }
          .to raise_error(DhanHQ::TokenExpiredError, /807|Token expired/)
      end
    end

    context "with unmapped error code" do
      let(:status) { 400 }
      let(:body) { { errorCode: "DH-999", errorMessage: "Unknown error" } }

      it "logs warning for unmapped error code" do
        expect(DhanHQ.logger).to receive(:warn).with(/Unmapped error code.*DH-999/)
        expect { helper.send(:handle_error, response) }
          .to raise_error(DhanHQ::InputExceptionError)
      end
    end

    context "when error is raised" do
      let(:status) { 400 }
      let(:body) { { errorCode: "DH-905", errorMessage: "Missing required fields, bad values for parameters etc." } }

      it "sets response_body on the exception with the parsed API payload" do
        error = nil
        begin
          helper.send(:handle_error, response)
        rescue DhanHQ::InputExceptionError => e
          error = e
        end
        expect(error).not_to be_nil
        expect(error.response_body).to be_a(Hash)
        expect(error.response_body[:errorCode]).to eq("DH-905")
        expect(error.response_body[:errorMessage]).to include("Missing required fields")
      end

      it "includes a hint for DH-905 that the API does not return field-level details" do
        expect { helper.send(:handle_error, response) }
          .to raise_error(DhanHQ::InputExceptionError, /API does not return which field failed/)
      end
    end

    context "when API returns extra error detail (errors array)" do
      let(:status) { 400 }
      let(:body) do
        { errorCode: "DH-905", errorMessage: "Validation failed",
          errors: ["securityId must be numeric", "price is required"] }
      end

      it "includes the extra detail in the message" do
        expect { helper.send(:handle_error, response) }
          .to raise_error(DhanHQ::InputExceptionError, /securityId must be numeric.*price is required/)
      end
    end
  end
end
