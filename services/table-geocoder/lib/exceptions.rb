# encoding: utf-8

module Carto
  module GeocoderErrors

    class AdditionalInfo
      SOURCE_CARTODB = 'cartodb'
      SOURCE_USER = 'user'

      attr_accessor :error_code, :title, :what_about, :source

      def initialize(error_code, title, what_about, source)
        self.error_code = error_code
        self.title = title
        self.what_about = what_about
        self.source = source
      end
    end

    class GeocoderBaseError < StandardError
      @@error_code_info_map = {}

      def self.register_additional_info(error_code, title, what_about, source)
        @additional_info = AdditionalInfo.new(error_code, title, what_about, source)
        @@error_code_info_map[@additional_info.error_code] = @additional_info
      end

      def self.get_info(error_code)
        @@error_code_info_map[error_code]
      end

      class << self
        attr_reader :additional_info
      end
    end

    # just a convenience
    def self.additional_info(error_code)
      GeocoderBaseError.get_info(error_code)
    end



    class MisconfiguredGmeGeocoderError < GeocoderBaseError
      register_additional_info(
        1000,
        'Google for Work account misconfigured',
        %q{Your Google for Work account seems to be incorrectly configured.
           Please <a href='mailto:sales@cartob.com?subject=Google for Work account misconfigured'>contact us</a>
           and we'll try to fix it quickly.}.squish,
        AdditionalInfo::SOURCE_USER
        )
    end

    class GmeGeocoderTimeoutError < GeocoderBaseError
      register_additional_info(
        1010,
        'Google geocoder timed out',
        %q{Your geocoding request timed out after several attempts.
           Please check your quota usage in the <a href='https://console.developers.google.com/'>Google Developers Console</a>
           and <a href='mailto:support@cartodb.com?subject=Google geocoder timed out'>contact us</a>
           if you are within the usage limits.}.squish,
        AdditionalInfo::SOURCE_USER
        )
    end


  end
end
