require 'cgi'
require 'uri'

module CartoDB

  module Importer2

    class ScrapingImporter
      SCRAPING_PARAMETER_CSS = 'cdb_extract_css'
      DEFAULT_FILENAME        = 'scraper'
      
      def self.is_scraping_request?(url)
        url =~ /#{SCRAPING_PARAMETER_CSS}/
      end

      def initialize(file_path, url, repository)
        @file_path = file_path
        @url = url
        @repository = repository
      end

      def extract
        css_selector = extract_css_selector_from_url(@url)
        name = "#{DEFAULT_FILENAME}_#{random_name}.csv"
        temp_name = filepath(name)
        run_css_scraping(@file_path, css_selector, temp_name)
        File.rename(temp_name, @file_path)
        name
      end

      private

      def extract_css_selector_from_url(url)
        CGI.parse(URI.parse(url).query)[SCRAPING_PARAMETER_CSS][0]
      end

      def run_css_scraping(source_file, css_selector, output_file)
        doc = get_document(source_file)
        table = doc.css(css_selector)
        data_matrix = extract_rows_from_table(table)
        write_data_matrix(data_matrix, output_file)
        data_matrix.count
      end

      # return an array of arrays, an array for each line with cells content
      def extract_rows_from_table(table)
        line_list = []
        table.search('tr').each { |row|
          cells = row.search('*/text()').collect {|text| text.to_s.gsub("\n", '')}
          line_list.append(cells)
        }
        line_list
      end

      def write_data_matrix(data_matrix, output_file)
        f = File.new(output_file, 'w:UTF-8')
        data_matrix.each { |line|
          f.write("#{line.join(',')}\n")
        }
      ensure
        f.close
      end

      def get_document(source_file)
        f = File.open(source_file)
        doc = Nokogiri::HTML(f)
        f.close
        doc
      end

      def random_name
        random_generator = Random.new
        name = ''
        10.times {
          name << (random_generator.rand*10).to_i.to_s
        }
        name
      end

      def filepath(name=nil)
        @repository.fullpath_for(name || filename)
      end

    end

  end

end
