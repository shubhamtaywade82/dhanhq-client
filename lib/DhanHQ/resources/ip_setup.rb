# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource for IP whitelist per API docs: GET /v2/ip/getIP, POST /v2/ip/setIP, PUT /v2/ip/modifyIP.
    # Set/Modify require dhanClientId, ip, ipFlag (PRIMARY | SECONDARY). See dhanhq.co/docs/v2/authentication/#setup-static-ip
    #
    # GET /v2/ip/getIP response: modifyDateSecondary, secondaryIP, modifyDatePrimary, primaryIP
    # (dates are YYYY-MM-DD from which the IP can be modified; IPs are IPv4 or IPv6).
    class IPSetup < BaseAPI
      API_TYPE  = :order_api
      HTTP_PATH = "/ip"

      def current
        get("/getIP")
      end

      # @param ip [String] Static IP (IPv4 or IPv6)
      # @param ip_flag [String] "PRIMARY" or "SECONDARY"
      # @param dhan_client_id [String, nil] Defaults to DhanHQ.configuration.client_id when nil
      def set(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)
        params = { ip: ip, ip_flag: ip_flag }
        params[:dhan_client_id] = dhan_client_id || DhanHQ.configuration&.client_id
        post("/setIP", params: params)
      end

      # @param ip [String] Static IP (IPv4 or IPv6)
      # @param ip_flag [String] "PRIMARY" or "SECONDARY"
      # @param dhan_client_id [String, nil] Defaults to DhanHQ.configuration.client_id when nil
      def update(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)
        params = { ip: ip, ip_flag: ip_flag }
        params[:dhan_client_id] = dhan_client_id || DhanHQ.configuration&.client_id
        put("/modifyIP", params: params)
      end
    end
  end
end
