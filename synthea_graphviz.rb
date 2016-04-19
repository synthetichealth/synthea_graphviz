#!/usr/bin/ruby

require 'graphviz'
require 'synthea'

# color (true) or black & white (false)
COLOR = true

# Create a new graph
g = GraphViz.new( :G, :type => :digraph )

# Create the list of items
items = []
modules = {}
Synthea::Rules.metadata.each do |key,rule|
  items << key
  items << rule[:inputs]
  items << rule[:outputs]
  modules[ rule[:module_name] ] = true
end
items = items.flatten.uniq

# Choose a color for each module
# available_colors = GraphViz::Utils::Colors::COLORS.keys
available_colors = ['palevioletred','orange','lightgoldenrod','palegreen','lightblue','lavender','purple']
modules.keys.each_with_index do |key,index|
  modules[key] = available_colors[index]
end
attribute_color = 'grey'

# Create a node for each item
nodes = {}
items.each{|i|nodes[i]=g.add_node(i.to_s)}

# Make items that are not rules boxes
components = nodes.keys - Synthea::Rules.metadata.keys
components.each do |i|
  nodes[i]['shape']='Box'
  if COLOR
    nodes[i]['color']=attribute_color
    nodes[i]['style']='filled'
  end
end

# Create the edges
edges = []

Synthea::Rules.metadata.each do |key,rule|
  node = nodes[key]
  if COLOR
    node['color'] = modules[rule[:module_name]]
    node['style'] = 'filled'
  end
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
