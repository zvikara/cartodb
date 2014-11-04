# encoding: utf-8

# This class takes a population, samples it and calculates the proportion of
# items in the population matching a given criterion.
#
# E.g:
#   # Given a list of numbers, estimate the proportion of odd numbers
#   population = population = (1..1000).to_a
#   tolerance = 0.05
#   guesser = CartoDB::Importer2::ColumnTypeGuesser.new(population, tolerance)
#   guesser.sample_proportion { |i| i % 3 == 0 }
#   => 0.33 # with 0.05 of error tolerance

module CartoDB
  module Importer2
    class ColumnTypeGuesser

      # Params:
      # - population: array-like object. It will be never fully scanned.
      # - tolerance: float in the range (0.0, 1.0)
      def initialize(population, tolerance, &match_criterion)
        @population = population
        @tolerance = tolerance
        @match_criterion = match_criterion
      end

      def sample_size
        @sample_size ||= [wald_min_sample_size, @population.size].min
      end

      # See http://en.wikipedia.org/wiki/Sample_size_determination#Estimating_proportions_and_means
      def wald_min_sample_size
        @wald_min_sample_size ||= (1.0 / @tolerance**2.0).ceil
      end

      def sample
        return @sample if @sample
        @sample = []
        i = sampling_start
        for n in (1..sample_size)
          @sample << @population[i]
          i = (i+sampling_step) % @population.size
        end
        @sample
      end

      def sampling_start
        @sampling_start ||= rand(0...@population.size)
      end

      def sampling_step
        @sampling_step ||= @population.size / sample_size
      end

      # Calculates the proportion of sample items meeting the criterion.
      # Params:
      # - &criterion: a block used to estimate the proportion of the population fulfilling the criterion.
      def sample_proportion(&criterion)
        (sample.count &criterion).to_f / sample.size
      end

    end
  end
end
