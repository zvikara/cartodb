# encoding: utf-8
require 'json'
require_relative '../../../../services/wms/proxy'

class Api::Json::WmsController < Api::ApplicationController
  ssl_required :index

  def proxy
    proxy = CartoDB::WMS::Proxy.new(params.fetch(:url))
    render_jsonp(proxy.serialize)
  end
end

