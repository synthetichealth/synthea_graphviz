#!/usr/bin/ruby

require 'graphviz'
require 'synthea'

# Create a new graph
g = GraphViz.new( :G, :type => :digraph )

# # Create two nodes
# hello = g.add_nodes( "Hello" )
# world = g.add_nodes( "World" )

# # Create an edge between the two nodes
# g.add_edges( hello, world )

# Create the list of items
items = []
Synthea::Rules.rules.each do |key,rule|
  items << key
  items << rule[:inputs]
  items << rule[:outputs]
end
items = items.flatten.uniq

# Create a node for each item
nodes = {}
items.each{|i|nodes[i]=g.add_node(i.to_s)}

# Make items that are not rules boxes
components = nodes.keys - Synthea::Rules.rules.keys
components.each{|i|nodes[i]['shape']='Box'}

# Create the edges
edges = []

Synthea::Rules.rules.each do |key,rule|
  node = nodes[key]
  begin
    rule[:inputs].each do |input|
      other = nodes[input]
      if !edges.include?("#{input}:#{key}")
        g.add_edge( other, node)
        edges << "#{input}:#{key}"
      end
    end
    rule[:outputs].each do |output|
      other = nodes[output]
      if !edges.include?("#{key}:#{output}")
        g.add_edge( node, other)
        edges << "#{key}:#{output}"
      end
    end
  rescue Exception => e
    binding.pry
  end
end

# Generate output image
g.output( :png => "synthea_rules.png" )
