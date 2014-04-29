module CartoDB
  module Datasources
    module Doubles
      class GoogleAPIClient

        attr_accessor application_name, authorization

        def initialize(params)
          application_name = params[:application_name]
        end

        def discovered_api
          nil
        end

      end #GoogleAPIClient

      class GoogleAPIAuthorization

        attr_accessor client_id, client_secret, scope, redirect_uri

      end #GoogleAPIAuthorization

    end #Doubles
  end #Datasources
end #CartoDB