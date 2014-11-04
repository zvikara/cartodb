# encoding: utf-8
require_relative '../../lib/importer/column_type_guesser'

describe CartoDB::Importer2::ColumnTypeGuesser do

  describe '#wald_min_sample_size' do
    it 'should return a sample size adequate to estimate the mean with a certain tolerance' do
      examples = [
        {tolerance: 0.1, sample_size: 100},
        {tolerance: 0.05, sample_size: 400},
        {tolerance: 0.03, sample_size: 1112},
        {tolerance: 0.01, sample_size: 10000}
      ]
      for example in examples do
        guesser = CartoDB::Importer2::ColumnTypeGuesser.new([], example[:tolerance])
        guesser.wald_min_sample_size.should == example[:sample_size]
      end
    end
  end

  describe '#sample_size' do
    it 'should not sample more than the population size' do
      CartoDB::Importer2::ColumnTypeGuesser.new([1,2], 0.05).sample_size.should == 2
      CartoDB::Importer2::ColumnTypeGuesser.new((1..1000).to_a, 0.05).sample_size.should == 400
    end
  end

  describe '#sampling_start' do
    it 'should be within the limits of the population' do
      CartoDB::Importer2::ColumnTypeGuesser.new((1..1000).to_a, 0.05).sampling_start.should be_between(0, 999)
    end
  end

  describe '#sample' do
    it 'should return a representative sample of the intended size' do
      population = (1..1000).to_a
      sample = CartoDB::Importer2::ColumnTypeGuesser.new(population, 0.05).sample
      sample.size.should == 400 # see a more complete test below
    end
  end

  describe '#sampling_step' do
    it 'should take the whole population if it is small' do
      CartoDB::Importer2::ColumnTypeGuesser.new([1,2], 0.05).sampling_step.should == 1
    end
    it 'should distribute the samples evenly accross the population' do
      CartoDB::Importer2::ColumnTypeGuesser.new((1..1000).to_a, 0.05).sampling_step.should == 2
    end
  end

  describe '#sample_proportion' do
    it 'should give a value within the tolerance of the population proportion matching the criterion' do
      population_proportion = 0.8
      tolerance = 0.05
      # generate a big population where 80% of the items are countries
      population = (1..10000).reduce([]) do |p, elem|
        elem = rand() < population_proportion ? :country : :anything_else
        p << elem
      end
      guesser = CartoDB::Importer2::ColumnTypeGuesser.new(population, tolerance)
      sample_proportion = guesser.sample_proportion {|x| x == :country}
      sample_proportion.should be_within(tolerance).of(population_proportion)
    end
  end

end
