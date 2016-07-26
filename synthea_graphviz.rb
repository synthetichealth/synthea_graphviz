#!/usr/bin/ruby

require 'graphviz'
require 'synthea'

# color (true) or black & white (false)
COLOR = true

def generateRulesBasedGraph()
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
end

def generateWorkflowBasedGraphs()
  Dir.glob('../synthea/lib/generic/modules/*.json') do |wf_file|
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph )

    # Create nodes based on states
    nodeMap = {}
    wf = JSON.parse(File.read(wf_file))
    wf['states'].each do |name, state|
      node = g.add_nodes(name, {'shape': 'record', 'style': 'rounded'})
      details = ''
      case state['type']
      when 'Initial', 'Terminal'
        node['color'] = 'black'
        node['style'] = 'rounded,filled'
        node['fontcolor'] = 'white'
      when 'Guard'
        details = logicDetails(state['allow'])
      when 'Delay'
        if state.has_key? 'range'
          r = state['range']
          details = "#{r['low']} - #{r['high']} #{r['unit']}"
        elsif state.has_key? 'exact'
          e = state['exact']
          details = "#{r['quantity']} #{r['unit']}"
        end 
      when 'Encounter'
        if state['wellness']
          details = 'Wait for regularly scheduled wellness encounter'
        end       
      end

      # Things common to many states
      if state.has_key? 'codes'
        state['codes'].each do |code|
          details = details + code['system'] + "[" + code['code'] + "]: " + code['display'] + "\\l"
        end
      end
      if state.has_key? 'target_encounter'
        verb = 'Perform'
        case state['type']
        when 'ConditionOnset'
          verb = 'Diagnose'
        when 'MedicationOrder'
          verb = 'Prescribe'
        end
        details = details + verb + " at " + state['target_encounter'] + "\\l"
      end
      if state.has_key? 'reason'
        details = details + "Reason: " + state['reason'] + "\\l"
      end
      node['label'] = details.empty? ? "{ #{name} | #{state['type']} }" : "{ #{name} | { #{state['type']} | #{details} } }"
      nodeMap[name] = node
    end

    # Create the edges based on the transitions
    wf['states'].each do |name, state|
      if state.has_key? 'direct_transition'
        g.add_edges( nodeMap[name], nodeMap[state['direct_transition']] )
      elsif state.has_key? 'distributed_transition'
        state['distributed_transition'].each do |t|
          pct = t['distribution'] * 100
          pct = pct.to_i if pct == pct.to_i
          g.add_edges( nodeMap[name], nodeMap[t['transition']], {'label': "#{pct}%"})
        end
      elsif state.has_key? 'conditional_transition'
        state['conditional_transition'].each_with_index do |t,i|
          cnd = t.has_key?('condition') ? logicDetails(t['condition']) : 'fallback'
          g.add_edges( nodeMap[name], nodeMap[t['transition']], {'label': "[#{i}] #{cnd}"})
        end
      end
    end

    # Generate output image
    g.output( :png => "#{wf['name']}.png" )
  end
end

def workflowNodeLabel(name, type, details = "")
  "{ #{name} | { #{type} | #{details} } }"
end

def logicDetails(logic)
  case logic['condition_type']
  when 'And', 'Or'
    subs = logic['conditions'].map do |c|
      if ['And','Or'].include?(c['condition_type'])
        "(\\l" + logicDetails(c) + ")\\l"
      else 
        logicDetails(c)
      end
    end
    subs.join(logic['condition_type'].downcase + ' ')
  when 'Not'
    c = logic['condition']
    if ['And','Or'].include?(c['condition_type'])
      "not (\\l" + logicDetails(c) + ")\\l"
    else
      "not " + logicDetails(c)
    end
  when 'Gender'
    "gender is '#{logic['gender']}'\\l"
  when 'Age'
    "age \\#{logic['operator']} #{logic['quantity']} #{logic['unit']}\\l"
  else
    "UNSUPPORTED_CONDITION(#{logic['condition_type']})\\l"
  end
end

generateRulesBasedGraph()
generateWorkflowBasedGraphs()

