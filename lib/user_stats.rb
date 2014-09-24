class UserStats
  
  def run_es_call(query)
    request_url = Cartodb.config[:api_requests_es_service]['url'].dup
    raise "Cannot run ES query. URL not available" if request_url.empty?
    request = Typhoeus::Request.new(
      request_url,
      method: :post,
      headers: { "Content-Type" => "application/json" },
      body: query
    )
    response = request.run
    if response.code != 200
      raise(response.body)
    end
    return response.body
  end

  def generate_fqueries(filters)
    fquery_template = {"fquery" => {"query"=>{"query_string"=>{}}}}
    filters.each do |f|
      fquery = fquery_template.dup
      k, v = f.split(":")
      fquery["query"]["query_string"]["query"] = "#{k}:(\"#{v}\")"
      raw_json["query"]["filtered"]["filter"]["bool"]["must"] << fquery
    end
  end

  def get_single_user_map_views(username, from, to)

    raw_json = 
    {
      "query" => {
        "filtered" => {
          "query" => {
            "query_string" => {
              "query" => "*"
            }
          },
          "filter" => {
            "bool" => {
              "must" => []
            }
          }
        }
      },
      "aggregations" => {
        "date" => {
          "date_histogram" => {
            "field" => "@timestamp", 
            "interval"=>"1d"
          }
        }
      }
    }
    
    if Cartodb.config[:api_requests_es_service]['filters'].empty?
      raise "Filters not found"
    else
      filters = Cartodb.config[:api_requests_es_service]['filters'].dup
      filters << "cdb-user:#{username}"
      raw_json["query"]["filtered"]["filter"]["bool"]["must"].merge(generate_fqueries(filters))
      raw_json["query"]["filtered"]["filter"]["bool"]["must"] << {"range"=>{"@timestamp"=>{"from"=>from_time, "to"=>to_time}}}
    end
    
    response = run_es_call(raw_json)
    values = {}
    JSON.parse(response)["aggregations"]["date"]["buckets"].each {|i| values[i['key']] = i['doc_count']}
    return values
  end
  
  def get_all_users_map_views(from, to)
    if Cartodb.config[:api_requests_es_service]['username_field'].empty?
      raise "Username field not found"
    else
      username_field = Cartodb.config[:api_requests_es_service]['username_field'].dup
    end

    raw_json = 
    {
      "query" => {
        "filtered" => {
          "query" => {
            "query_string" => {
              "query" => "*"
            }
          },
          "filter" => {
            "bool"=> {
              "must" => []
            }
          }
        }
      },
      "aggregations" => {
        "username" => {
          "terms" => {
            "field" => username_field, 
            "size"=> 0
          },
          "aggregations" => {
            "date" => {
              "date_histogram" => {
                "field" => "@timestamp", 
                "interval" => "1d"
              }
            }
          }
        }
      }
    }
   
    if Cartodb.config[:api_requests_es_service]['filters'].empty?
      raise "Filters not found"
    else
      filters = Cartodb.config[:api_requests_es_service]['filters'].dup
      raw_json["query"]["filtered"]["filter"]["bool"]["must"].merge(generate_fqueries(filters))
      raw_json["query"]["filtered"]["filter"]["bool"]["must"] << {"range"=>{"@timestamp"=>{"from"=>from_time, "to"=>to_time}}}
    end
    
    response = run_es_call(raw_json)
    values = {}
    users = JSON.parse(response)["aggregations"]["username"]["buckets"]
    users.each do |u|
      dates = {}
      u["date"]["buckets"].each do |d|
        dates[d['key']] = d['doc_count']
      end
      values[u['key']] = dates
    end
    return values
  end

end
