module Xapit
  module Server
    class Indexer
      def initialize(data)
        @data = data
      end

      def document
        document = Xapian::Document.new
        document.data = "#{@data[:class]}-#{@data[:id]}"
        terms.each do |term, weight|
          document.add_term(term, weight)
          Xapit.database.xapian_database.add_spelling(term, weight)
        end
        values.each do |index, value|
          document.add_value(index, value)
        end
        document
      end

      def terms
        base_terms + text_terms + field_terms + facet_terms
      end

      def values
        values = {}
        each_value do |index, value|
          if values[index]
            values[index] += "\3#{value}" # multiple values are split back out on the query side
          else
            values[index] = value
          end
        end
        values
      end

      def text_terms
        each_attribute(:text) do |name, value, options|
          value.to_s.downcase.split.map do |term|
            [term, options[:weight] || 1]
          end
        end.flatten(1)
      end

      def field_terms
        each_attribute(:field) do |name, value, options|
          ["X#{name}-#{parse_field(value)}", 1]
        end
      end

      def facet_terms
        each_attribute(:facet) do |name, value, options|
          ["F#{Xapit.facet_identifier(name, value)}", 1]
        end
      end

      private

      def base_terms
        [["C#{@data[:class]}", 1], ["Q#{@data[:class]}-#{@data[:id]}", 1]]
      end

      def parse_field(value)
        if value.kind_of? Time
          value.to_i
        else
          value.to_s.downcase
        end
      end

      def each_value
        each_attribute(:field) do |name, value, options|
          yield(Xapit.value_index(:field, name), Xapit.serialize_value(value))
        end
        each_attribute(:sortable) do |name, value, options|
          yield(Xapit.value_index(:sortable, name), Xapit.serialize_value(value))
        end
        each_attribute(:facet) do |name, value, options|
          yield(Xapit.value_index(:facet, name), value)
        end
      end

      def each_attribute(type)
        if @data[:attributes]
          @data[:attributes].map do |name, options|
            if options.has_key? type
              if options[:value].kind_of? Array
                options[:value].map { |value| yield(name, value, options[type]) }
              else
                [yield(name, options[:value], options[type])]
              end
            end
          end.compact.flatten(1)
        else
          []
        end
      end
    end
  end
end
